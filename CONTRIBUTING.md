# Contributing

Keep this repository subscription-free by default. Do not add cloud credentials,
deployment jobs, personal datasets or private project files.

Before opening a pull request:

1. Run the Node syntax checks, tests and audit described in the README.
2. Run Terraform format/validate/mock tests and OPA positive/negative tests.
3. Add regression tests for changed behavior or new guardrails.
4. Keep checks fail-closed and document any narrowly scoped IaC exception.
5. Inspect the Git diff and generated lockfile changes for secrets and unrelated files.

CI reports are available on workflow runs; Snyk is explicitly optional and never
runs on pull requests. Maintainers should require the `required` status check
before merging. Do not infer production or cloud compliance from a mocked test.
