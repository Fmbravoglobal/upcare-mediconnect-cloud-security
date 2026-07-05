# HL7 Data-Handling Notes

Infrastructure-layer considerations for HL7-formatted data (e.g., HL7 v2 messages between the EHR module and lab/pharmacy integrations, or FHIR resources for modern API-based exchange). This is not a full HL7 implementation guide — it documents what the infrastructure layer must support so the application layer can implement HL7 exchange correctly and securely.

## What the infrastructure layer is responsible for

1. **Transport security for HL7 message exchange**
   - HL7 v2 messages sent over MLLP (Minimal Lower Layer Protocol) must be wrapped in TLS when traversing any network the infra layer controls — plaintext MLLP is not acceptable for PHI-bearing lab/pharmacy integrations.
   - HL7 FHIR (REST/JSON-based) exchange goes through the same WAF-fronted, TLS 1.2+ enforced ingress as other API traffic (`terraform/modules/aws-waf`, `terraform/modules/azure-frontdoor-waf`).

2. **Network segmentation for integration partners**
   - Third-party lab/pharmacy/insurer systems exchanging HL7 data connect through a dedicated integration endpoint, not directly into the PHI data tier — enforced by the app-tier-only ingress rule on the database security group (`terraform/modules/aws-rds-encrypted`).
   - Per-partner API keys or mTLS certificates, scoped to specific message types/endpoints where the integration platform supports it.

3. **Storage of HL7 payloads**
   - Raw HL7 messages (v2 or FHIR resources) containing PHI are subject to the same encryption-at-rest requirements as structured EHR data — if persisted (e.g., for audit/replay), they go in the PHI-tier encrypted storage (S3 with KMS, or Azure Blob with customer-managed key), never in unencrypted logs.
   - **Caution**: HL7 v2 messages routinely appear in application logs during debugging — the CI/CD pipeline's secret-scanning step (gitleaks) does not catch PHI-in-logs by pattern; this must be enforced at the application logging-configuration level (out of this repo's scope, but flagged here as a known gap).

4. **Audit trail for HL7 message exchange**
   - Every inbound/outbound HL7 message exchange with a third party should be logged (message type, sender, timestamp, success/failure) at the integration gateway level — this feeds the same audit-control requirement as database access logging (HIPAA §164.312(b)).

## Known Gap / Flagged for Application-Layer Follow-Up

- This repo does not implement an HL7 parsing/validation layer (schema validation, ACK/NACK handling) — that's an application-service concern. The infrastructure layer's job is to ensure whatever service does that work sits behind the same Zero Trust, encrypted, audited perimeter as every other PHI-adjacent service.
- If PHI is found appearing in plaintext logs (a common HL7 integration mistake), that is an application-logging-configuration fix, not an infrastructure fix — flagged here so it isn't missed during a security review of the full stack.
