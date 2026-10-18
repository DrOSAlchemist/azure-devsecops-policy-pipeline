# Engineering notes

This is the implementation guide for my Azure DevSecOps Policy Pipeline.
The [README](../README.md) explains the project and reproducible commands; this
document follows the code paths and the decisions behind them.

## 1. Keep the application small enough to understand

I used native Node.js modules rather than introducing a web framework just to
serve a project page and two JSON endpoints. That keeps the application dependency
audit simple, but makes the HTTP contract my responsibility.

### Request flow

[`src/server.js`](../src/server.js) exports `makeServer` so tests can create a
real HTTP server on an ephemeral loopback port without starting the CLI entry
point. Production startup and test setup share the same request handler.

```text
Incoming request
  |
  +-- method other than GET/HEAD --> drain request, return 405 + Allow
  |
  +-- remove query suffix; retain the exact path
       |
       +-- /healthz       --> minimal liveness JSON
       +-- /api/controls  --> static control inventory
       +-- / or /style.css --> read the allowlisted asset
       |                     +-- read failure --> log code, return 500
       +-- everything else --> return 404
```

The handler never concatenates a request path onto a filesystem path. It also
does not decode incoming paths into new routes. Asset names come from a fixed
map; unknown and encoded traversal paths are tested using raw HTTP requests so
the client cannot normalize them away before the test reaches the server.

The shared response helper applies the same security headers to successful and
error responses and omits the body for HEAD. The content security policy permits
only a same-origin stylesheet, with no scripts, framing or form submission.
There is no HSTS claim: local requests use HTTP, and future TLS termination would
need its own validated configuration.

### Lifecycle and configuration

`parsePort` rejects partial numbers, out-of-range values and empty strings rather
than silently selecting a different port. CLI startup binds to `0.0.0.0` for
container use; tests bind explicitly to loopback. Server errors are logged and set
a failing process exit code.

Headers and requests have timeouts, and the header count is bounded. These
settings are not a rate limiter or a complete denial-of-service defense.
SIGINT/SIGTERM stop new connections and close idle connections; a ten-second
deadline prevents indefinite shutdown.

[`src/controls.js`](../src/controls.js) holds six tool descriptions and their
limitations. `/api/controls` serializes those declarations with
`cloudDeployed: false`. It is intentionally not connected to GitHub, Azure or
scanner APIs. The UI is static HTML/CSS, not a live compliance dashboard.

## 2. Separate infrastructure shape from cloud execution

[`infra/main.tf`](../infra/main.tf) declares a resource group, Linux service
plan, Linux web app, custom HTTPS policy definition and resource-group assignment.
The app depends on the assignment in the declared graph. That ordering expresses
intent; it is not evidence of Azure Policy propagation or actual enforcement.

The app declaration requires HTTPS, disables FTP/basic publishing, uses a
system-assigned identity and configures TLS, health checks and diagnostic logging.
The service plan illustrates two workers and zone balancing. It is not a tested
regional deployment or a cost recommendation.

[`variables.tf`](../infra/variables.tf) validates names, ownership and digest
syntax. [`versions.tf`](../infra/versions.tf) constrains Terraform and AzureRM;
the committed [lockfile](../infra/.terraform.lock.hcl) contains provider
checksums for reproducible initialization. [`outputs.tf`](../infra/outputs.tf)
returns the planned app name, not a deployed URL.

The mock provider in
[`security.tftest.hcl`](../infra/tests/security.tftest.hcl) supplies syntactically
valid placeholder resource IDs and runs `command = plan`. Six assertions check:

1. HTTPS-only transport.
2. The declared TLS baseline.
3. System-assigned managed identity.
4. Disabled FTP and webdeploy basic authentication.
5. Enabled policy assignment enforcement.
6. A deny effect in the policy rule.

Provider schema validation and mocked planning catch configuration errors without
Azure credentials. They cannot test permissions, quotas, alias behavior, image
pulls, diagnostics delivery or an actual health probe in Azure.

## 3. Evaluate the plan that the test actually generated

A fixture-only policy test would be easy to disconnect from the Terraform code.
[`scripts/extract-plan.js`](../scripts/extract-plan.js) bridges that gap:

1. Parse Terraform's JSONL test-event stream.
2. Select `test_plan` events.
3. Require exactly one plan with nonempty `resource_changes`.
4. Write the plan using exclusive creation (`flag: 'wx'`).

Malformed JSON, missing plans, duplicate plans and empty changes fail explicitly.
An existing output fails rather than being overwritten. That protects against
accidentally evaluating stale evidence during local reruns; it is not an
attestation or cryptographic freshness guarantee. CI runs the extractor only
after Terraform exits successfully.

[`tests/extract-plan.test.js`](../tests/extract-plan.test.js) spawns the actual
script in a temporary directory. It checks both exit status and output contents,
including preservation of a pre-existing file.

## 4. Make project policy explicit

[`policy/terraform.rego`](../policy/terraform.rego) defaults `allow` to false
and collects human-readable reasons in `deny`. Acceptance requires that the deny
set is empty. The rule set expects this project's five managed resource types,
not an arbitrary Azure estate.

The policy checks required tags, explicit web-app transport/identity settings,
a digest-pinned container reference, the exact HTTPS deny-rule structure and
enabled assignment enforcement. It rejects managed-resource deletions and
unsupported managed types. Because required settings must positively satisfy
the rule, missing values cannot be treated as passing defaults.

[`terraform_test.rego`](../policy/terraform_test.rego) builds a known-good plan
and mutates one concern at a time. Twelve named tests cover good input, invalid
plan shapes, absent types, missing values, insecure settings, mutable images,
deletions, unexpected types, an audit-only definition and disabled enforcement.
Some tests iterate several mutations, so twelve tests are not just twelve input
examples.

To inspect denial reasons on a generated local plan:

```sh
.tools/opa eval --format pretty --data policy/terraform.rego \
  --input reports/plan.json 'data.terraform.guardrails.deny'
```

That command is diagnostic; the CI gate separately uses `--fail` and
`data.terraform.guardrails.allow == true`. Printing an empty set alone is not
the gate.

The [OPA installer](../scripts/install-opa.sh) selects a supported platform
binary and verifies the release's SHA-256 sidecar before making it executable.
This checks download integrity against the published checksum, not an independent
signature or a reproducible-build attestation.

## 5. Test the runtime artifact, not only its Dockerfile

The [Dockerfile](../Dockerfile) starts from a digest-pinned Node 24 Alpine image,
removes unused npm/Yarn, copies only the manifest and runtime files, and switches
to the existing non-root `node` user. No application dependency install is needed.
The [.dockerignore](../.dockerignore) allowlists the image context, excluding
Terraform, reports, repository metadata and local tooling.

The workflow adds constraints at runtime: read-only filesystem, dropped Linux
capabilities, `no-new-privileges`, a PID limit and a loopback-only host port.
It asserts a nonzero user ID and absence of package-manager paths, then waits
for `/healthz` with bounded retries. These assertions complement the Dockerfile
health check; they do not turn the container into a production isolation boundary.

Trivy then scans the final image filesystem for high/critical vulnerabilities.
Only after that gate passes is the CycloneDX SBOM generated. The
[remediation record](operations.md#initial-image-finding-and-mitigation) explains
why removing unused tooling was a concrete fix rather than suppressing advisories.

## 6. Keep CI acceptance separate from merge protection

The [workflow](../.github/workflows/ci.yml) has seven jobs. Four independent jobs
check source, infrastructure/policy, configuration and the repository filesystem.
Snyk is conditional. The image job waits for acceptable upstream results; the
final `required` job checks every result even when upstream jobs fail.

Snyk runs only when `SNYK_ENABLED=true` and the event is not a pull request.
An enabled job with no token fails. A disabled job is reported as not run.
Nothing here grants cloud permissions, pushes an image or runs Terraform apply.

Pinning direct action revisions and scanner versions reduces accidental changes
in tool selection. It does not freeze hosted runner images, transitive package
resolution, advisory databases or external services. The
[maintenance guide](operations.md) describes the update/review loop.

There are four [scoped Checkov exceptions](security-exceptions.md) for the public,
stateless demo. They are architectural decisions requiring review, not a claim
that every possible control passed.

GitHub must separately require the `required` status check through branch
protection or rulesets. A passing workflow file does not configure that setting.
I keep this distinction explicit because a check that can be ignored at merge
time is not an enforced repository acceptance policy.

## 7. Extending this project

| Change | Code and evidence to update together |
| --- | --- |
| Add an HTTP endpoint | Route handling, HTTP tests and the README contract; avoid request-derived filesystem paths |
| Add runtime dependencies | Manifest/lockfile, dependency audit, container install strategy and image scan; npm is absent from the final runtime |
| Add an Azure resource | Terraform, mock test, OPA allowed types/controls, negative tests and Checkov review |
| Change policy requirements | Rego rules and rejecting mutations, then generated-plan evaluation |
| Change the base image | Digest, package-manager-removal paths/assertions, Docker smoke test, scan and SBOM |
| Add live deployment | Separate approved design for credentials, state, image publication, cost, networking, rollback and runtime verification |

I have not implemented registry publication, production deployment, image signing,
live Azure Policy tests or automatic remediation. Those are distinct engineering
increments, not capabilities implied by the presence of Terraform or scanners.
