# HIPAA Security Rule Control Matrix

Maps HIPAA Security Rule safeguards to the specific technical controls implemented in this repository. This is infrastructure-layer evidence only — application-layer controls (e.g., session timeout in the patient portal UI) are documented in the relevant service repo.

## Administrative Safeguards (§164.308)

| Safeguard | Requirement | Implementation | Evidence |
|---|---|---|---|
| Security Management Process §164.308(a)(1) | Risk analysis and management | STRIDE threat model conducted for the infra layer | `architecture/threat-model.md` |
| Workforce Security §164.308(a)(3) | Access authorization/clearance procedures | Centralized identity, permission sets mapped to roles, JIT elevation via PIM | ADR 0003, `terraform/modules/*/iam*` |
| Information Access Management §164.308(a)(4) | Access authorization | Least-privilege IAM roles/RBAC per module | ADR 0003, Terraform IAM policies |
| Security Awareness & Training §164.308(a)(5) | Workforce training | Out of scope for this repo — tracked at org level | N/A |
| Contingency Plan §164.308(a)(7) | Data backup, disaster recovery | RDS Multi-AZ + 35-day backup retention; Azure SQL geo-redundancy (to be configured) | `terraform/modules/aws-rds-encrypted/main.tf` |

## Physical Safeguards (§164.310)

| Safeguard | Requirement | Implementation | Evidence |
|---|---|---|---|
| Facility Access Controls §164.310(a)(1) | Physical facility security | Inherited from AWS/Azure data center certifications (SOC 2, ISO 27001) — cloud provider responsibility under shared responsibility model | AWS/Azure compliance documentation (external) |
| Workstation/Device Security §164.310(b)/(c) | Device-level controls | Entra ID Conditional Access device posture checks required for elevated access | ADR 0001, ADR 0003 |

## Technical Safeguards (§164.312)

| Safeguard | Requirement | Implementation | Evidence |
|---|---|---|---|
| Access Control §164.312(a)(1) | Unique user ID, emergency access, automatic logoff, encryption | IAM Identity Center/Entra ID unique identities; short-lived tokens; JIT elevation with auto-expiry | ADR 0001, ADR 0003, `architecture/architecture-diagrams.md` (sequence diagram) |
| Audit Controls §164.312(b) | Record and examine activity in systems with PHI | CloudTrail + Azure Activity Log capture all API calls; Azure SQL extended auditing policy; RDS CloudWatch log exports | `terraform/modules/aws-rds-encrypted/main.tf`, `terraform/modules/azure-sql-encrypted/main.tf` |
| Integrity §164.312(c)(1) | Protect PHI from improper alteration/destruction | S3 versioning + deletion protection on RDS; Key Vault purge protection | `cloudformation/ehr-storage-stack.yaml`, `terraform/modules/azure-keyvault/main.tf` |
| Person or Entity Authentication §164.312(d) | Verify identity before access | MFA enforced at IdP level (Entra Conditional Access / IAM Identity Center) | ADR 0001, ADR 0003 |
| Transmission Security §164.312(e)(1) | Encrypt PHI in transit | TLS 1.2+ enforced (`rds.force_ssl=1`, Azure SQL `minimum_tls_version=1.2`, WAF/Front Door TLS termination) | `terraform/modules/aws-rds-encrypted/main.tf`, `terraform/modules/azure-sql-encrypted/main.tf`, policy `policies/opa/mandatory-encryption.rego` |

## Encryption at Rest — Detail

| Data store | Encryption mechanism | Key management |
|---|---|---|
| AWS RDS (EHR database) | AES-256, storage_encrypted=true | Customer-managed KMS key, annual rotation (`terraform/modules/aws-kms`) |
| AWS S3 (EHR documents) | SSE-KMS | Dedicated KMS key per CloudFormation stack, annual rotation |
| Azure SQL (EHR database) | Transparent Data Encryption (TDE) | Customer-managed key in Key Vault Premium (HSM-backed), annual rotation |
| Azure Key Vault | HSM-backed keys | Premium SKU, purge protection enabled |

## Business Associate Agreement (BAA) Considerations

Not all AWS/Azure services are covered under a standard BAA. Before any new service is added to `terraform/modules/`, confirm BAA eligibility:

- **AWS**: verify against the current AWS HIPAA Eligible Services Reference before use for any PHI-adjacent workload.
- **Azure**: verify against the current Microsoft Azure HIPAA/HITECH implementation guidance and covered-services list.
- Services used in this repo (RDS, S3, KMS, Azure SQL, Key Vault, VNet/VPC networking) are commonly BAA-eligible on both platforms as of this writing, but eligibility and covered-service lists change — re-verify at implementation time, not from this document alone.

## Gaps / Not Yet Implemented

- Formal Business Associate Agreements are an organizational/legal artifact, not a technical control — must be executed with AWS and Microsoft directly, outside this repo's scope.
- Workforce security awareness training (§164.308(a)(5)) is an organizational process, tracked outside this repo.
- Full contingency plan / disaster recovery runbook beyond database backup config — planned for a future phase.
