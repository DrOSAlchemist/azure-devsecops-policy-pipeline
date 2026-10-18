# Maintenance and remediation

## Triage a failed run

1. Open the failed job and inspect the scanner error or assertion. Download its
   artifact if available; a missing artifact after a setup failure is not a pass.
2. Distinguish tool/network/authentication failures from actual findings. Repair
   setup failures and rerun; do not change exit codes to hide them.
3. For dependency/image findings, identify the affected package, installed version,
   advisory and fixed version. Update the manifest/lock or reviewed base-image
   digest; rerun tests and all relevant scans.
4. For IaC findings, correct the resource setting and add a rejecting OPA test or
   Terraform assertion where appropriate. Never weaken a control solely to make
   CI green.
5. For secret findings, verify privately. Revoke and rotate an exposed credential
   before cleaning Git history. Do not print credentials in issues or logs.
6. If no fix exists, block acceptance or obtain a narrowly scoped, documented
   risk decision. This reference provides no automatic exception mechanism for
   vulnerability findings.

Dependabot opens reviewable updates for actions, npm, Terraform and Docker.
Scanner CLI pins in workflow/requirements files need deliberate maintenance.
The weekly scheduled workflow catches new advisories even without source changes.
No bot automatically merges fixes or edits production infrastructure.

## Pin upgrades

- Verify upstream action commits and release provenance before updating pins.
- Keep the Node base-image digest and illustrative Terraform image input aligned,
  while remembering neither is a published application image.
- Run `terraform providers lock` for Linux amd64 and macOS ARM64 after changing
  the provider; commit `.terraform.lock.hcl`.
- Keep installer/documentation/CI OPA versions consistent.
- Test the Snyk CLI download/bootstrap without a token after changing its pin.
- Revisit all four Checkov exceptions when storage, identity or network design changes.

## Trust boundaries

Pull requests use read-only repository permissions, no cloud tokens and no Snyk
secrets. There is no `pull_request_target`, deployment environment, OIDC
`id-token: write`, registry push or Terraform apply. Actions and scanner releases
are pinned; hosted runner images and vulnerability databases still evolve.
CI executes contributed application/tests on ephemeral hosted runners.

Artifacts can include resource names and configuration. Only mock-generated
plans from this public demonstration are uploaded. Never adapt that artifact step
to a real plan containing secrets without designing redaction and access controls.

## Local scanners

Checkov requires Python 3.12 (CI uses that version):

```sh
python3.12 -m venv .tools/checkov-venv
.tools/checkov-venv/bin/pip install -r requirements-security.txt
.tools/checkov-venv/bin/checkov --directory . --framework terraform dockerfile
```

After installing Trivy 0.76.0 from its official release:

```sh
trivy fs --scanners vuln,secret --severity HIGH,CRITICAL --exit-code 1 .
```

Image builds are optional locally. CI builds an ephemeral image, tests it with a
read-only filesystem/no capabilities, scans it, emits an SBOM and never pushes it.
No cloud or website deployment procedure is included by design.

## Initial image finding and mitigation

The first successful container smoke test exposed four **high-severity** findings
in the pinned Node image's bundled npm dependencies, not in application packages:

| Package in bundled npm | Version | High-severity advisory |
| --- | --- | --- |
| brace-expansion | 5.0.9 | CVE-2026-102276, CVE-2026-102278 |
| http-cache-semantics | 4.2.0 | CVE-2026-93748 |
| undici | 6.28.0 | CVE-2026-19534 |

The [retained failed run](https://github.com/DrOSAlchemist/azure-devsecops-policy-pipeline/actions/runs/39171500931)
contains the original Trivy JSON. A corroborating GitHub-advisory dependency scan
also reported two medium and one low advisory across those packages. This was a
tool-based scan, not an inference that the server's own Node HTTP code is affected.

Because this dependency-free server never installs packages at runtime, the
Dockerfile removes the **entire bundled npm tree and unused Yarn installation**,
including their launcher links. No advisory suppression, `ignore-unfixed` flag
or scan soft-fail was added. CI asserts the package-manager paths are absent,
tests the image and rescans its final filesystem. Future base-image updates
must preserve those tests and still pass the independent Trivy gate.

Removal narrows installed runtime attack surface; original base layers remain
part of the image history. It is not a claim that the upstream base image was
patched or that Node's built-in libraries have no vulnerabilities. Consult the
latest run's SBOM and scan output for the current result.
