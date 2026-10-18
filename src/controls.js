export const controls = Object.freeze([
  { tool: 'Node.js', stage: 'Source', purpose: 'Syntax checks, HTTP regression tests, dependency audit', boundary: 'Passing tests are not a security audit.' },
  { tool: 'Checkov', stage: 'Infrastructure', purpose: 'Scan Terraform and Dockerfile configuration', boundary: 'Documented exceptions are scoped by check ID and resource.' },
  { tool: 'OPA', stage: 'Policy', purpose: 'Test and enforce Terraform plan guardrails', boundary: 'CI uses mocked-provider plans, not an authenticated Azure plan.' },
  { tool: 'Trivy', stage: 'Filesystem and image', purpose: 'Detect secrets and high/critical vulnerabilities before accepting the image', boundary: 'Database and scanner failures fail the job; findings depend on available advisories.' },
  { tool: 'Snyk', stage: 'Optional authenticated scan', purpose: 'Dependency and IaC scanning when explicitly enabled', boundary: 'Requires a Snyk account/token and eligible entitlement. Not an open-source-only or credential-free gate.' },
  { tool: 'Azure Policy', stage: 'Cloud template', purpose: 'Resource-group-scoped deny policy for non-HTTPS web apps', boundary: 'Definition and assignment are code only. Nothing is deployed or enforced in Azure.' },
]);
