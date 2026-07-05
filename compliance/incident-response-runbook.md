# Incident Response Runbook — PHI Breach Scenario

Scope: infrastructure-layer incident response for a suspected or confirmed PHI exposure/breach in AWS or Azure. This runbook complements, not replaces, org-level incident response policy and legal/compliance breach-notification procedures.

## Severity Classification

| Level | Criteria | Example |
|---|---|---|
| SEV-1 | Confirmed unauthorized access to or exfiltration of PHI | Public S3 bucket containing EHR documents discovered accessible; database credentials leaked and used |
| SEV-2 | Suspected unauthorized access, not yet confirmed | GuardDuty/Sentinel alert on anomalous access pattern to PHI-tier resource |
| SEV-3 | Policy/control violation with no evidence of access | Policy gate bypassed via emergency deploy; misconfiguration caught by drift detection before exploitation |

## Detection → Containment → Eradication → Recovery → Notification

### 1. Detection
Sources that can trigger this runbook:
- GuardDuty / Security Hub finding (AWS)
- Microsoft Defender for Cloud / Sentinel analytics rule (Azure)
- Policy gate failure caught post-deploy via drift detection
- Manual report (internal or external, e.g., security researcher disclosure)

**Immediate action:** On-call engineer confirms the finding is not a false positive using the relevant audit log (CloudTrail / Azure Activity Log) and classifies severity per the table above.

### 2. Containment
- **SEV-1**: Immediately revoke the exposed credential or close the exposed resource. Examples:
  - Public S3/Blob exposure → apply `PublicAccessBlockConfiguration` / disable public network access immediately via console or emergency `terraform apply`, bypassing normal PR review (documented exception, reviewed post-incident).
  - Leaked DB credential → rotate immediately via KMS/Key Vault-backed secret rotation; invalidate all active sessions.
  - Compromised IAM/Entra identity → disable the identity in IAM Identity Center / Entra ID immediately; this revokes access across both clouds per ADR 0003's centralized identity design.
- **SEV-2**: Increase logging verbosity on the affected resource; do not yet make production changes until access pattern is confirmed malicious (avoid destroying evidence).
- **SEV-3**: Correct the misconfiguration via standard PR + policy gate; no emergency bypass needed.

### 3. Eradication
- Identify root cause: misconfiguration, credential compromise, vulnerable dependency, insider action, third-party integration compromise.
- Patch the underlying gap: update the relevant Terraform module, add/tighten an OPA policy rule if the gate should have caught this, rotate any related credentials beyond the immediately affected one.

### 4. Recovery
- Restore normal service via the standard CI/CD pipeline (not emergency bypass) once root cause is patched.
- Verify the policy gate now catches the class of misconfiguration that caused the incident (add a regression test / OPA rule if it didn't already exist).

### 5. Notification (HIPAA Breach Notification Rule)
For confirmed SEV-1 PHI breaches, HIPAA's Breach Notification Rule imposes specific timelines — this is a legal/compliance process, not a purely technical one:

- **Affected individuals**: notification without unreasonable delay, no later than 60 days from discovery.
- **HHS Office for Civil Rights**: notification required; timing depends on whether the breach affects 500+ individuals (without unreasonable delay, ≤60 days) or fewer (annual log, within 60 days of year-end).
- **Media notification**: required if breach affects 500+ residents of a state/jurisdiction.
- **This runbook's role**: the infrastructure/engineering team supplies the technical facts (what data, how many records, how it was accessed, when discovered, when contained) to legal/compliance, who own the actual notification process and timeline compliance.

## Post-Incident

- Full timeline written up: discovery time, containment time, root cause, remediation, notification status.
- Add compliance evidence entry to `compliance/evidence/` documenting the incident and remediation (supports the audit trail requirement).
- Review whether the STRIDE threat model (`architecture/threat-model.md`) needs an update — was this an anticipated threat with a control that failed, or an unanticipated threat requiring a new mitigation?

## Break-Glass Access Procedure

For SEV-1 incidents requiring immediate elevated access beyond normal PIM/JIT limits:
1. On-call engineer requests break-glass access via the designated emergency account (separate from normal PIM flow, pre-provisioned and monitored).
2. Break-glass account usage triggers an immediate, non-suppressible alert to the security lead and engineering manager.
3. All actions taken under break-glass access are logged and reviewed within 24 hours, regardless of incident outcome.
4. Break-glass credentials are rotated after every use, whether or not the incident was confirmed.
