# Security Controls Summary — UpCare MediConnect Cloud Infrastructure

*One-page reference. For full detail, see `compliance/hipaa-control-matrix.md` and the individual ADRs in `architecture/adrs/`.*

## Identity & Access
- Centralized workforce identity: AWS IAM Identity Center (SSO) + Azure Entra ID — no standalone per-account IAM users for humans
- Just-in-time, time-bound elevation (Entra PIM) for any write access to PHI-tier resources; standing access is read-only at most
- MFA + device posture enforced via Conditional Access before any authentication succeeds

## Network
- Zero Trust: identity is the primary control plane, network position is defense-in-depth only
- AWS: multi-AZ VPC, PHI data tier in private subnets with no internet route
- Azure: hub-spoke topology, Azure Firewall inspects all spoke egress, PHI services isolated in a dedicated spoke with Private Endpoints
- WAF at every public edge (AWS WAF + managed rule sets, Azure Front Door WAF Premium) with rate limiting

## Encryption
- At rest: customer-managed KMS keys (AWS) / HSM-backed Key Vault keys (Azure), annual rotation enforced in code
- In transit: TLS 1.2+ enforced at the database parameter/config level, not just the edge
- No default cloud-managed encryption keys used for PHI-bearing resources

## Infrastructure as Code & CI/CD
- Terraform (multi-cloud) + CloudFormation (AWS parallel evidence), fully modularized
- 4 OPA/Rego policies gate every plan: no public storage, mandatory encryption, mandatory tagging, no unrestricted ingress
- 9-stage GitHub Actions pipeline: lint → SAST (Checkov/tfsec/cfn-nag) → secret scanning (gitleaks) → SCA → policy gate → manual approval → apply → DAST (OWASP ZAP) → compliance evidence export

## Monitoring & Detection
- AWS: GuardDuty + Security Hub (CIS + AWS Foundational Security Best Practices), EventBridge-routed high-severity alerts
- Azure: Defender for Cloud (SQL/Servers/Key Vault/Storage plans) + Sentinel analytics rules
- 3 tested detection scenarios: unauthorized PHI access, encryption drift, anomalous data egress

## Compliance
- Full HIPAA Security Rule control matrix (Administrative, Physical, Technical safeguards) mapped to specific implemented controls
- PHI-breach incident response runbook with severity classification and break-glass procedure
- HL7 data-handling considerations documented for downstream application-layer implementation
- Gaps and BAA considerations documented explicitly, not omitted

## Cloud Platforms
AWS + Azure (multi-cloud), architecturally symmetric to allow shared policy-as-code enforcement across both.
