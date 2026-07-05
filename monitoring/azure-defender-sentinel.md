# Azure Monitoring — Defender for Cloud + Sentinel

Configuration reference for the Azure side of the monitoring/detection layer. Represented here as documented configuration rather than a full Terraform module because Sentinel analytics rules are most maintainable authored/versioned as ARM/Bicep or via the `azurerm_sentinel_alert_rule_*` resources once the Log Analytics workspace (a shared-services dependency) is provisioned — flagged as a Phase 5b follow-up.

## Microsoft Defender for Cloud

- **Enable Defender plans** for: Servers, SQL (critical — covers the PHI-tier Azure SQL databases), Key Vault, Storage, App Service.
- **Defender for SQL** specifically covers:
  - Vulnerability assessment on the EHR database
  - Advanced Threat Protection — detects anomalous query patterns, potential SQL injection, brute-force login attempts against `upcare-<env>-sql`
- **Auto-provisioning**: enable Log Analytics agent auto-provisioning so all compute resources report into the central workspace without manual per-resource setup.

## Microsoft Sentinel

- **Data connectors** to enable:
  - Azure Activity Log (captures all control-plane operations — required for §164.312(b) audit control)
  - Azure SQL Auditing logs (wired from `azurerm_mssql_server_extended_auditing_policy` in the azure-sql-encrypted module)
  - Microsoft Entra ID sign-in and audit logs (identity-layer visibility, ties back to ADR 0003)
  - Azure Firewall logs (from the hub VNet — see `terraform/modules/azure-vnet`)

- **Analytics rules (minimum set for this platform):**
  1. **Anomalous PHI database access** — alert on Azure SQL sign-in from an identity with no PIM elevation record for the corresponding time window.
  2. **Firewall policy drift** — alert if Azure Firewall rule collection is modified outside of a recognized Terraform apply (tagged deployment principal).
  3. **Impossible travel / anomalous sign-in** — built-in Entra ID Identity Protection risk detection, surfaced into Sentinel incidents.
  4. **Key Vault access anomaly** — alert on access to the PHI encryption key (`azurerm_key_vault_key.phi_encryption`) outside of expected service principals.

- **Incident response integration**: Sentinel incidents for anything matching SEV-1/SEV-2 in `compliance/incident-response-runbook.md` should trigger a playbook (Logic App) that posts to the on-call notification channel — implementation deferred to org-specific tooling (Teams/Slack/PagerDuty), not hardcoded here.

## Retention

- Log Analytics workspace retention set to 365 days minimum to match the RDS/S3 and Azure SQL audit log retention already configured, keeping evidence windows consistent across both clouds.
