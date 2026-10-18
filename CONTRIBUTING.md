# Contributing

Keep this repository subscription-free by default. Do not add cloud credentials,
deployment jobs, personal datasets or private project files.

Start with the [engineering notes](docs/engineering.md) for the code paths and
design decisions. The application is intentionally small; changes should improve
behavior or evidence, not add tools solely to lengthen the stack list.

Before opening a pull request:

1. Run the Node syntax checks, tests and audit described in the README.
2. Run Terraform format/validate/mock tests and OPA positive/negative tests.
3. Add regression tests for changed behavior or new guardrails.
4. Keep checks fail-closed and document any narrowly scoped IaC exception.
5. Inspect the Git diff and generated lockfile changes for secrets and unrelated files.

CI reports are available on workflow runs; Snyk is explicitly optional and never
runs on pull requests. Maintainers should require the `required` status check
before merging. Do not infer production or cloud compliance from a mocked test.

## Documentation and project voice

Use direct engineering language: describe the problem, the implementation,
the trade-off and how to verify it. The README and project page use the
DrOSAlchemist first-person voice for decisions visible in this repository,
not invented career history, customer results or production experience.
Keep code comments focused on non-obvious constraints; put walkthroughs in
the engineering notes instead of repeating the implementation above each function.

Link claims to code, tests or dated workflow runs. Label historical scan counts
with their run/date; link to current CI rather than presenting old results as
live status. Keep API field names, Terraform defaults and documentation aligned.
Do not remove tool limitations or scoped exceptions to make the project sound
more impressive.
