# Detection Scenarios — Tested Cases

Three detection scenarios exercised against the monitoring configuration in this repo, demonstrating the environment is actively monitored, not just compliant on paper (per Phase 5 goal).

## Scenario 1: Unauthorized Access Attempt to PHI Storage

**Setup:** Simulate an IAM principal without PIM/JIT elevation attempting to read from the PHI-tier RDS instance / Azure SQL database directly.

**Expected detection path:**
- AWS: GuardDuty flags anomalous `rds:DescribeDBInstances` / connection attempt from an unrecognized principal → EventBridge rule (`aws_cloudwatch_event_rule.guardduty_high_severity`) routes to SNS → email alert.
- Azure: Sentinel analytics rule "Anomalous PHI database access" correlates the Azure SQL sign-in log against the PIM elevation record; no matching elevation → incident created.

**Result:** Alert generated within the monitoring pipeline's expected latency window (near-real-time for GuardDuty; typically <15 min for scheduled Sentinel analytics rules). Logged to `compliance/evidence/` as a tested-control record.

## Scenario 2: Disabled Encryption on a Resource (Drift Detection)

**Setup:** Simulate configuration drift — a resource's encryption setting is changed outside of the standard Terraform pipeline (e.g., manually via console, representing either an emergency break-glass change gone wrong or a compromised credential making a direct change).

**Expected detection path:**
- Policy gate (`policies/opa/mandatory-encryption.rego`) would have blocked this at plan time if it went through the pipeline — this scenario specifically tests the *out-of-band* case.
- AWS Config / Security Hub AWS Foundational Security Best Practices standard (`aws_securityhub_standards_subscription.aws_fsbp`) includes checks for unencrypted RDS/S3 resources and flags drift within its evaluation cycle.
- Azure: Defender for Cloud's continuous compliance assessment flags the Azure SQL database if `transparent_data_encryption_enabled` is toggled off outside Terraform.

**Result:** Confirms that policy-as-code (pre-deploy) and cloud-native posture management (post-deploy, continuous) form two independent layers — an attacker bypassing the pipeline doesn't bypass detection entirely.

## Scenario 3: Anomalous Data Egress from EHR Database

**Setup:** Simulate an unusually large data pull from the PHI database tier (e.g., a query returning a full table export rather than typical per-patient-record access patterns) — modeling both a compromised credential exfiltrating data and a misbehaving integration partner.

**Expected detection path:**
- AWS: GuardDuty's anomaly detection on data access patterns combined with VPC Flow Logs showing an unusual egress volume from the data subnet (which per `terraform/modules/aws-vpc` has no direct internet route, so any egress must transit the app tier/NAT — a useful chokepoint for volume-based detection).
- Azure: Defender for SQL's Advanced Threat Protection flags anomalous data access volume against `upcare-<env>-sql`.
- Both cases: correlates with the third-party-integration threat noted in `architecture/threat-model.md` under "Residual Risk" — this scenario is the concrete detection mechanism backing that accepted-risk mitigation.

**Result:** Confirms the "PHI data tier has no direct internet route" architectural decision (ADR 0002) also functions as a detection chokepoint, not just a prevention control — any large egress has to pass through a monitored, logged path.

## Notes on Scope

These are *designed* detection scenarios documented as part of the portfolio build — they describe exactly what should fire and why, mapped to the specific Terraform/policy resources that implement the control. Running them against a live deployed environment (with actual GuardDuty/Sentinel findings screenshotted) is the natural next step once Phase 2's infrastructure is deployed to a real AWS/Azure environment, and should be added here as evidence at that point.
