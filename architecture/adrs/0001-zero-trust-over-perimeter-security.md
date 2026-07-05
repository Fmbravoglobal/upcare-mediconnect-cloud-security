# ADR 0001: Zero Trust Architecture over Traditional Perimeter Security

## Status
Accepted

## Context
UpCare MediConnect handles PHI across multiple modules (patient management, EHR, telehealth, billing, AI insights) and multiple actor types (patients, doctors, nurses, admin staff, third-party lab/pharmacy/insurance integrations). A traditional perimeter model — "trusted" internal network, firewall at the edge, VPN for remote access — assumes that anything inside the network boundary is safe. That assumption breaks down for a system with:

- Remote and mobile access from clinical staff and patients
- Multiple third-party integrations that must reach specific services without broad network access
- Regulatory requirement (HIPAA Security Rule, Technical Safeguards §164.312) for access control and audit at the level of individual users and data types, not network segments

A single compromised credential or misconfigured VPN inside a perimeter model can expose the entire internal network, including PHI-bearing services that had no direct business relationship with the compromised entry point.

## Decision
Adopt a Zero Trust architecture: every request is authenticated and authorized regardless of network origin, with no implicit trust granted by being "inside" the VPC/VNet.

Concretely:
- **AWS**: IAM Identity Center (SSO) for workforce identity, Verified Access for application-layer access control instead of a flat VPN, microsegmented security groups per service tier
- **Azure**: Entra ID Conditional Access policies, Private Link/Private Endpoint for PaaS services, network security groups scoped per subnet/service
- Identity (user + device posture) is the primary control plane; network position is a secondary, defense-in-depth layer only

## Consequences

**Positive:**
- Blast radius of a single compromised credential is limited to the specific resources that identity is authorized for
- Access control and audit logging naturally align to HIPAA's per-user accountability requirement
- Third-party integrations (labs, pharmacies, insurers) can be granted narrow, service-specific access without broad network trust
- Supports remote/mobile clinical staff access without a traditional VPN attack surface

**Negative / tradeoffs:**
- Higher initial design and implementation complexity than a flat network + perimeter firewall
- Requires mature identity provider setup (Entra ID / IAM Identity Center) before other work can proceed — this is a dependency for Phase 1 completion
- Slightly higher latency per request due to continuous authorization checks (acceptable given PHI sensitivity)

## Alternatives Considered
- **Traditional perimeter + VPN**: rejected — does not meet least-privilege expectations for PHI systems and creates a single high-value target (the VPN) for attackers
- **Hybrid (perimeter for internal-only services, Zero Trust for patient-facing)**: rejected for consistency — mixed models increase the chance of misconfiguration at the boundary between the two, and PHI can flow through internal-only services too (e.g., billing, AI insights)
