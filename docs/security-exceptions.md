# Scoped Checkov exceptions

These are **design limitations**, not evidence of compliance. Suppressions are
inline on `azurerm_linux_web_app.demo`, not global skips or soft failures.
Review on every architecture change and before any production reuse.

| Check | Reason in this reference | Production follow-up |
| --- | --- | --- |
| CKV_AZURE_13: App Service Authentication | Public static demo has no accounts, privileged operations or stored user data. | Design identity and authorization before adding protected functionality. |
| CKV_AZURE_17: Client certificates | A publicly readable portfolio endpoint does not enroll mutual-TLS clients. | Reassess mTLS for service-to-service/private endpoints; HTTPS remains mandatory. |
| CKV_AZURE_88: Azure Files | Stateless container uses its image filesystem and has no persistent storage requirement. | Design storage, encryption, backup and recovery if state is introduced. |
| CKV_AZURE_222: Disable public network access | Public demo ingress is intentional. | Add private ingress, access restrictions or an approved edge architecture for protected workloads. |

Health checks, managed identity, TLS, FTP restrictions, diagnostics, zone
balancing and all other discovered checks remain enabled. Checkov's version is
pinned; upgrading it can introduce new checks that require review. OPA adds
project-specific controls but does not erase these exceptions.

This list does not authorize scan-wide exclusions or permanent vulnerability
ignores. New exceptions require a narrow scope, justification, maintainer review
and a documented production follow-up.
