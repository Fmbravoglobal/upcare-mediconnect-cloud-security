# Threat Model — UpCare MediConnect Infrastructure Layer
### Method: STRIDE

Scope: infrastructure, identity, and network layer only (per repo scope — application-layer threats belong in each service repo's own threat model, though noted here where they drive infra controls).

## Assets

| Asset | Sensitivity |
|---|---|
| PHI in EHR data store (AWS RDS / Azure SQL) | Critical — regulated (HIPAA) |
| Telehealth media streams (live video/audio) | Critical — regulated (HIPAA, contains PHI) |
| Billing/insurance records | High — PII + financial |
| AI insight models & training data | High — derived from PHI |
| Third-party integration credentials (labs, pharmacy, insurers) | High |
| Workforce identity (IAM Identity Center / Entra ID) | Critical — root of all access |
| Infrastructure-as-code state & pipeline credentials | Critical — compromise = full environment compromise |

## Actors

- Patients (external, via portal/mobile app)
- Doctors, nurses, admin staff (internal, via web app, possibly remote)
- Third-party systems: labs, pharmacies, insurance providers (external, API-integrated)
- Platform engineers / on-call (internal, infra-level access)
- External attackers (unauthenticated, credential-stuffing, supply-chain)

## STRIDE Analysis

### Spoofing
- **Threat:** Attacker impersonates a clinician or patient to access PHI.
- **Mitigation:** MFA enforced via Entra ID Conditional Access / IAM Identity Center for all workforce accounts; patient-facing auth via OAuth 2.0/JWT short-lived tokens; no shared service accounts for human access (ADR 0003).
- **Threat:** Third-party integration (lab/pharmacy) credential spoofed.
- **Mitigation:** mTLS or signed API keys per integration partner, scoped to specific endpoints only, rotated on a defined schedule.

### Tampering
- **Threat:** PHI modified in transit or at rest without authorization.
- **Mitigation:** TLS 1.2+ enforced on all channels (ADR 0001); encryption at rest via KMS/Key Vault; database-level audit logging on write operations to PHI tables.
- **Threat:** Terraform state or IaC pipeline tampered with to inject malicious infrastructure changes.
- **Mitigation:** Remote state with locking (S3+DynamoDB / Azure Storage+lease), signed commits, branch protection, mandatory policy-as-code gate (Phase 2/3) before any `apply`.

### Repudiation
- **Threat:** A user or admin denies having accessed/modified PHI.
- **Mitigation:** CloudTrail (AWS) and Azure Activity Log capture every API call tied to an authenticated identity; centralized, immutable log storage (write-once, restricted delete permissions) satisfies HIPAA §164.312(b) audit control requirement.

### Information Disclosure
- **Threat:** PHI exposed via misconfigured public storage bucket/blob container.
- **Mitigation:** Policy-as-code gate (OPA/Conftest) blocks any public storage resource at plan time (Phase 2); no PHI-tier resource has a public endpoint (private networking by default per ADR 0002).
- **Threat:** PHI exposed via overly broad IAM role or NSG rule.
- **Mitigation:** Least-privilege IAM/RBAC per module (ADR 0003); policy gate blocks overly permissive security groups/NSGs.
- **Threat:** Secrets (DB credentials, API keys) leaked via committed code or logs.
- **Mitigation:** Secret scanning (gitleaks) in CI pipeline (Phase 3); secrets stored in KMS-backed Secrets Manager / Key Vault, never in code or environment files.

### Denial of Service
- **Threat:** Patient portal or telehealth service overwhelmed, denying clinical access during care delivery.
- **Mitigation:** WAF (AWS WAF / Azure Front Door WAF) with rate limiting at the edge; DDoS Protection Standard on the Azure hub (ADR 0002); auto-scaling compute tiers.

### Elevation of Privilege
- **Threat:** Compromised low-privilege credential used to escalate to PHI-tier admin access.
- **Mitigation:** JIT/PIM-gated elevation for any PHI-tier write access (ADR 0003) — no standing privileged access exists to escalate into; permission boundaries on AWS IAM roles prevent self-escalation even if a role is compromised.

## Residual Risk / Accepted Risk

- **Third-party integration compromise upstream** (e.g., a lab's system is breached and sends malicious/malformed data): infra layer can validate schema and rate-limit ingestion but cannot fully prevent a legitimate, authenticated partner's own compromise. Accepted risk, mitigated by input validation at the API gateway and monitoring for anomalous data volume/pattern from any single integration (Phase 5 detection scenario).
- **Insider threat with legitimately elevated access during an active PIM session**: mitigated but not eliminated by JIT access + audit logging; full elimination would require session recording/DLP, out of scope for this infra-layer build.
