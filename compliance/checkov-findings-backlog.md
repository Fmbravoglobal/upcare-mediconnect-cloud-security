# Checkov Findings Backlog

Results from the first full Checkov scan across `terraform/` and `cloudformation/`. Per the pipeline's soft-fail policy (see `.github/workflows/security-pipeline.yml`), these findings do not block merges — they are triaged here and scheduled for remediation, consistent with how a security team handles SAST output at scale: fix the non-negotiables via policy-as-code gates, track everything else.

## Already Fixed (Phase 2 remediation)
- CKV_AWS_118 — RDS enhanced monitoring — fixed via `aws_iam_role.rds_enhanced_monitoring` + `monitoring_interval`
- CKV_AWS_226 — RDS auto minor version upgrade — fixed via `auto_minor_version_upgrade = true`
- CKV_AWS_161 — RDS IAM authentication — fixed via `iam_database_authentication_enabled = true`
- CKV_AWS_353 — RDS Performance Insights — fixed via `performance_insights_enabled = true`
- CKV_AWS_382 (false positive) — empty egress rule flagged despite `cidr_blocks = []` — documented with `checkov:skip`
- False positive on NAT Gateway EIP-to-instance association — documented with `checkov:skip`

## Open — AWS

| Check | Resource | File | Priority | Notes |
|---|---|---|---|---|
| CKV_AWS_192 | `aws_wafv2_web_acl.this` | `terraform/modules/aws-waf/main.tf` | Medium | Add explicit Log4j/CVE-2021-44228 managed rule group alongside existing Common + SQLi rule sets |
| CKV2_AWS_12 | `aws_vpc.this` (default SG) | `terraform/modules/aws-vpc/main.tf` | Medium | Add explicit `aws_default_security_group` resource with no ingress/egress rules |
| CKV2_AWS_31 | `aws_wafv2_web_acl.this` | `terraform/modules/aws-waf/main.tf` | Low | Add `aws_wafv2_web_acl_logging_configuration` pointing to a dedicated log destination |
| CKV2_AWS_3 (GuardDuty org scope) | `aws_guardduty_detector.this` | `monitoring/aws-guardduty-securityhub.tf` | Low | Add `aws_guardduty_organization_admin_account` if this becomes a multi-account org; single-account use is acceptable as-is |

## Open — Azure

| Check | Resource | File | Priority | Notes |
|---|---|---|---|---|
| CKV_AZURE_40 | `azurerm_key_vault_key.phi_encryption` | `terraform/modules/azure-keyvault/main.tf` | Medium | Add `expiration_date` on the key in addition to the existing rotation policy |
| CKV_AZURE_229 | `azurerm_mssql_database.ehr` | `terraform/modules/azure-sql-encrypted/main.tf` | Medium | Evaluate zone-redundant SKU tier — cost/availability tradeoff, needs a decision, not just a flag flip |
| CKV_AZURE_224 | `azurerm_mssql_database.ehr` | `terraform/modules/azure-sql-encrypted/main.tf` | Low | Enable Ledger feature for cryptographic proof of data integrity — evaluate performance impact first |
| CKV_AZURE_216 | `azurerm_firewall.hub` | `terraform/modules/azure-vnet/main.tf` | Medium | Add explicit `dns` block with `proxy_enabled` and configure a Firewall Policy with `IntelMode = Deny` |
| CKV_AZURE_219 | `azurerm_firewall.hub` | `terraform/modules/azure-vnet/main.tf` | Medium | Attach an `azurerm_firewall_policy` resource — currently rule collections would need to be added directly, a policy resource is the modern pattern |
| CKV2_AZURE_2 | `azurerm_mssql_server.phi` | `terraform/modules/azure-sql-encrypted/main.tf` | Medium | Enable Vulnerability Assessment with a dedicated storage account for scan results |
| CKV2_AZURE_27 | `azurerm_mssql_server.phi` | `terraform/modules/azure-sql-encrypted/main.tf` | Medium | Add Azure AD authentication alongside SQL auth (`azuread_administrator` block) |
| CKV2_AZURE_31 (x2) | `azurerm_subnet.phi_app`, `phi_data`, `nonphi_app` | `terraform/modules/azure-vnet/main.tf` | High | Attach explicit NSGs to each subnet — currently relying on hub firewall only; defense-in-depth gap |

## Open — CloudFormation

| Check | Resource | File | Priority | Notes |
|---|---|---|---|---|
| CKV_AWS_18 | `AccessLogsBucket` | `cloudformation/ehr-storage-stack.yaml` | Low | Access-logs bucket itself has no access logging configured — acceptable to skip (logging the logger is generally not required) but flagged for awareness |
| CKV_AWS_21 | `AccessLogsBucket` | `cloudformation/ehr-storage-stack.yaml` | Low | Enable versioning on the access-logs bucket |

## Triage Rationale

**High priority** (subnet NSGs): this is a real defense-in-depth gap — currently PHI subnets rely solely on the hub firewall for inbound/outbound filtering. Scheduled for the next infrastructure sprint.

**Medium priority**: mostly missing "nice to have" hardening (WAF logging, Key Vault key expiration, Azure AD auth alongside SQL auth) — real gaps, not urgent, no PHI exposure risk in current state.

**Low priority**: findings on non-PHI-bearing resources (access-logs bucket) or features requiring a cost/performance tradeoff decision before implementation (Ledger, zone redundancy).

**Not fixing**: the two documented `checkov:skip` false positives — re-verify these skip justifications any time the underlying Checkov policy version updates, since false-positive behavior can change between releases.
