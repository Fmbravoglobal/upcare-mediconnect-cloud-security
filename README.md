# UpCare MediConnect — Cloud Security Infrastructure

Multi-cloud (AWS + Azure) security infrastructure for **UpCare MediConnect**, an AI-driven healthcare ITES platform. This repository contains the infrastructure-as-code, identity and network architecture, CI/CD security pipeline, and compliance documentation that the application layer (patient management, EHR, telehealth, billing, AI insights) runs on.

**Scope of this repo:** cloud security engineering — infrastructure, identity, network, encryption, CI/CD gates, monitoring, and HIPAA/HL7 control mapping. Application code (React/Node/Django services) is out of scope here and lives in separate service repos.

## Why this exists

Healthcare platforms handling PHI need infrastructure that is secure and auditable by default, not bolted on after the fact. This repo demonstrates a Zero Trust, least-privilege, encrypted-by-default approach to standing up the infrastructure layer for a multi-module healthcare platform across two cloud providers.

## Repository Structure

```
architecture/       System architecture diagrams and Architecture Decision Records (ADRs)
  adrs/              Individual ADRs documenting key design decisions and tradeoffs
terraform/
  aws/               AWS root modules (VPC, compute, RDS, KMS, WAF)
  azure/             Azure root modules (VNet, compute, SQL, Key Vault, Front Door WAF)
  modules/           Shared, reusable Terraform modules
cloudformation/      AWS CloudFormation stacks (parallel IaC evidence, EHR storage tier)
policies/            Policy-as-code (OPA/Conftest, Sentinel, IAM/SCP JSON)
ci-cd/               GitHub Actions security pipeline workflows
compliance/          HIPAA/HL7 control matrices, incident response runbook
  evidence/          Auto-generated scan/compliance evidence artifacts from CI
monitoring/          CloudWatch, Azure Monitor, Sentinel, and detection scenario configs
docs/                Supporting documentation
```

## Compliance Posture

Target frameworks: **HIPAA Security Rule** (Administrative, Physical, Technical safeguards) and **HL7** data-handling conventions for structured health data exchange. See `compliance/hipaa-control-matrix.md` (Phase 4) for the full control-to-implementation mapping.

## Architecture Principles

1. **Zero Trust by default** — no implicit trust based on network location; every request authenticated and authorized.
2. **Least privilege everywhere** — IAM roles and RBAC scoped per module (patient mgmt, billing, telehealth, AI insights), not per team.
3. **Encrypted at rest and in transit** — KMS/Key Vault-managed keys, TLS 1.2+ enforced, no exceptions for "internal" traffic.
4. **Private by default** — no public storage, no public database endpoints; access via private networking (Private Link/Private Endpoints) or authenticated gateways only.
5. **Everything scanned before merge** — Checkov, tfsec, cfn-nag/cfn-lint, gitleaks, and OPA policy gates run in CI before any `apply`.
6. **Auditable by design** — CloudTrail, Azure Activity Log, and centralized detection rules (GuardDuty, Microsoft Defender for Cloud) from day one, not added post-incident.

## Status

- [x] Phase 0 — Foundations & repo structure
- [x] Phase 1 — Cloud security architecture (Zero Trust, IAM, network design)
- [x] Phase 2 — Infrastructure as code (Terraform + CloudFormation)
- [x] Phase 3 — CI/CD security pipeline
- [x] Phase 4 — Compliance & documentation
- [x] Phase 5 — Monitoring, detection & response
- [x] Phase 6 — Portfolio packaging

---

## Case Study: Securing a Multi-Cloud Healthcare Platform

### Problem
UpCare MediConnect is a healthcare ITES platform spanning patient management, EHR, telehealth, billing, and AI-driven insights — all of it touching PHI, all of it needing to satisfy HIPAA Security Rule requirements, and deployed across both AWS and Azure. The infrastructure layer needed to be secure and auditable by default, not retrofitted after a breach.

### Architecture
Three foundational decisions shaped everything downstream, documented as ADRs rather than left implicit:
- **Zero Trust over perimeter security** ([ADR 0001](architecture/adrs/0001-zero-trust-over-perimeter-security.md)) — identity, not network position, is the primary control plane.
- **Hub-spoke over flat VNet** ([ADR 0002](architecture/adrs/0002-hub-spoke-over-flat-vnet.md)) — centralized egress inspection and blast-radius containment between PHI and non-PHI workloads.
- **Centralized identity with JIT elevation** ([ADR 0003](architecture/adrs/0003-centralized-identity-over-standalone-iam.md)) — IAM Identity Center + Entra PIM, no standing privileged access to PHI-tier resources.

A [STRIDE threat model](architecture/threat-model.md) and [Mermaid architecture diagrams](architecture/architecture-diagrams.md) validate those decisions against concrete threats before any infrastructure code was written.

### Implementation
- **Infrastructure as code**: symmetric Terraform module sets for AWS (VPC, KMS, RDS, WAF) and Azure (hub-spoke VNet, Key Vault, SQL with customer-managed TDE, Front Door WAF), plus a parallel CloudFormation stack for the EHR document tier — demonstrating both tools produce the same security posture (`terraform/`, `cloudformation/`).
- **Policy as code**: four OPA/Rego policies (`policies/opa/`) enforcing no public storage, mandatory encryption, mandatory tagging, and no unrestricted ingress — gate every `terraform plan` before `apply`.
- **CI/CD security pipeline**: a nine-stage GitHub Actions workflow (`.github/workflows/security-pipeline.yml`) — lint → SAST → secret scanning → SCA → policy gate → manual approval → apply → DAST → compliance evidence export.

### Compliance Outcome
Every implemented control is mapped explicitly to a HIPAA Security Rule safeguard in the [HIPAA control matrix](compliance/hipaa-control-matrix.md), with gaps honestly flagged rather than glossed over. A [PHI-breach incident response runbook](compliance/incident-response-runbook.md) and [HL7 data-handling notes](compliance/hl7-data-handling.md) round out the compliance layer. [Three tested detection scenarios](monitoring/detection-scenarios.md) confirm the environment is actively monitored (GuardDuty/Security Hub on AWS, Defender for Cloud/Sentinel on Azure), not just compliant on paper.

### What I'd do at scale
- Stand up a real Log Analytics workspace and wire the Sentinel analytics rules described in `monitoring/azure-defender-sentinel.md` as actual `azurerm_sentinel_alert_rule_*` Terraform resources rather than documentation.
- Add the compute tier (ECS/EKS or AKS) module referenced as a TODO in `terraform/aws/main.tf`, closing the placeholder security-group wiring.
- Execute the detection scenarios against a live deployment and replace the "designed scenario" writeups with real screenshots/finding IDs as evidence.
- Formalize BAAs with AWS and Microsoft and track service eligibility changes over time rather than as a point-in-time note.

---

## License

Portfolio/demonstration project. Not affiliated with any commercial UpCare MediConnect deployment.
