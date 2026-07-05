# ADR 0002: Hub-Spoke VNet Topology over Flat VNet (Azure)

## Status
Accepted

## Context
UpCare MediConnect's Azure footprint needs to host multiple distinct workloads with different risk profiles: PHI-bearing services (EHR, patient records), non-PHI services (marketing/informational content, internal tooling), and shared services (logging, identity, CI/CD runners). A flat VNet — everything in one address space with subnet-level NSGs only — is simpler to stand up but makes consistent policy enforcement and network-level containment harder as the number of services grows.

Per ADR 0001, network position is a secondary control layer behind identity, but it still matters for defense-in-depth, egress control, and centralizing inspection (Azure Firewall, DDoS protection) rather than duplicating it per service.

## Decision
Use a hub-spoke VNet topology:
- **Hub VNet**: Azure Firewall, DDoS Protection Standard, centralized DNS, VPN/ExpressRoute gateway if hybrid connectivity is needed later
- **Spoke VNets**: one per workload tier (e.g., PHI-services spoke, non-PHI-services spoke, shared/CI-CD spoke), peered to the hub, with all internet-bound and cross-spoke traffic routed through the hub firewall
- PaaS services (Azure SQL, Cosmos DB, Key Vault) use Private Endpoints within the relevant spoke — no public endpoints

## Consequences

**Positive:**
- Centralized egress inspection and logging — one firewall policy to audit, not N per-service policies
- Clear blast-radius containment: a compromised non-PHI spoke cannot directly reach the PHI spoke without passing through hub-enforced rules
- Scales cleanly as new modules (telehealth, AI insights, billing) are added as new spokes without re-architecting the hub
- Matches common enterprise landing-zone patterns, which is useful both operationally and as a recognizable pattern to reviewers/auditors

**Negative / tradeoffs:**
- More Terraform modules and peering configuration to maintain than a flat VNet
- Hub becomes a critical dependency — firewall misconfiguration or outage affects all spokes' egress; mitigated with firewall HA SKU and change-controlled policy updates
- Slightly higher cost (Azure Firewall + DDoS Standard) than a flat VNet with only NSGs

## Alternatives Considered
- **Flat VNet with subnet-level NSGs only**: rejected — acceptable for a small single-team app, but insufficient containment and audit clarity once PHI and non-PHI workloads share address space and the module count grows (per the platform's stated scope of 7+ core modules)
- **Fully isolated VNets per workload (no peering, no hub)**: rejected — eliminates blast-radius benefits of a shared inspection point but multiplies operational overhead (N separate firewalls/NAT gateways, no centralized logging) for no meaningful security gain over hub-spoke
