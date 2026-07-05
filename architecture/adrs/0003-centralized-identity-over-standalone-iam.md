# ADR 0003: Centralized Workforce Identity (IAM Identity Center / Entra PIM) over Standalone Per-Account IAM

## Status
Accepted

## Context
UpCare MediConnect spans multiple modules and, per ADR 0002, multiple network zones across two clouds. Workforce access (engineers, on-call staff, and eventually clinical admin operators) needs to reach AWS and Azure resources for deployment, incident response, and support. Standalone IAM — individual IAM users per AWS account, individual Azure AD (Entra) users assigned RBAC roles directly per subscription — is the default starting point but does not scale safely:

- Credentials and permissions drift across accounts/subscriptions with no single source of truth
- No consistent way to enforce time-bound, just-in-time elevated access for sensitive operations (e.g., direct access to the PHI database tier)
- HIPAA's audit requirements (§164.312(b)) are harder to satisfy when access grants are scattered across N account-level IAM configurations rather than centrally logged

## Decision
Centralize workforce identity:
- **AWS**: IAM Identity Center (SSO) as the single point of workforce authentication across all AWS accounts, with permission sets mapped to least-privilege roles per module/environment; no standalone IAM users for humans
- **Azure**: Entra ID as the identity provider, with Privileged Identity Management (PIM) enforcing just-in-time, time-bound elevation for any role touching PHI-bearing resources (e.g., Azure SQL admin, Key Vault access policies)
- Standing (non-JIT) access is limited to read-only/monitoring roles; any write access to PHI-tier resources requires PIM activation with justification and automatic expiry

## Consequences

**Positive:**
- Single source of truth for who has access to what, across both clouds — directly supports HIPAA audit and access-review requirements
- JIT elevation via PIM means standing privileged access to PHI systems is effectively zero, shrinking the attack surface for credential compromise
- Easier offboarding — disabling one identity provider account revokes access across both clouds, rather than hunting down per-account IAM users
- Consistent with the Zero Trust decision in ADR 0001 (identity as primary control plane)

**Negative / tradeoffs:**
- Requires upfront investment in identity provider configuration (permission sets, PIM policies, approval workflows) before teams can get any access — a Phase 1 dependency
- JIT elevation adds friction for legitimate urgent access (e.g., production incident); mitigated with a documented break-glass procedure with post-hoc audit review
- Two identity systems (IAM Identity Center + Entra ID) rather than one — acceptable tradeoff of true multi-cloud federation complexity vs. the security benefit of using each cloud's native, best-supported identity tooling

## Alternatives Considered
- **Standalone per-account/per-subscription IAM users**: rejected — does not scale, fails centralized audit requirements, and standing access to PHI resources is a persistent risk
- **Single federated identity broker across both clouds with custom-built JIT tooling**: rejected for this stage — high build/maintenance cost for a portfolio-stage project; native IAM Identity Center + Entra PIM cover the same JIT/least-privilege goals with far less custom code, and can be revisited if true cross-cloud SSO becomes a hard requirement later
