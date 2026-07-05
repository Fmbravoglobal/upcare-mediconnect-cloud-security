# Architecture Diagrams

## 1. Multi-Cloud Network Topology (AWS + Azure)

```mermaid
flowchart TB
    subgraph Internet
        Patient[Patient - Web/Mobile]
        Clinician[Clinician - Web/Mobile]
        ThirdParty[Lab / Pharmacy / Insurer APIs]
    end

    subgraph AWS["AWS Account"]
        AWSWAF[AWS WAF + ALB]
        subgraph AWSVPC["VPC - Multi-AZ"]
            AWSPublic[Public Subnet: ALB only]
            AWSAppTier[Private Subnet: App/Compute Tier]
            AWSDataTier[Private Subnet: RDS - EHR/PHI, KMS-encrypted]
        end
        GuardDuty[GuardDuty + Security Hub]
    end

    subgraph Azure["Azure Subscription"]
        AFD[Azure Front Door + WAF]
        subgraph Hub["Hub VNet"]
            AzFirewall[Azure Firewall]
        end
        subgraph SpokePHI["Spoke: PHI Services VNet"]
            AzApp[App Tier - Telehealth/Billing]
            AzSQL[Azure SQL - Private Endpoint, encrypted]
        end
        subgraph SpokeNonPHI["Spoke: Non-PHI Services VNet"]
            AzInfo[Informational/Marketing Services]
        end
        Sentinel[Microsoft Defender for Cloud + Sentinel]
    end

    subgraph Identity["Centralized Identity"]
        IDC[AWS IAM Identity Center - SSO]
        Entra[Entra ID + PIM]
    end

    Patient -->|TLS 1.2+| AWSWAF
    Clinician -->|TLS 1.2+, MFA| AFD
    ThirdParty -->|mTLS / signed API keys| AWSWAF

    AWSWAF --> AWSPublic --> AWSAppTier --> AWSDataTier
    AFD --> AzFirewall --> AzApp --> AzSQL
    AzFirewall -.->|inspected egress| SpokeNonPHI

    IDC -.->|JIT elevation| AWSAppTier
    IDC -.->|JIT elevation| AWSDataTier
    Entra -.->|PIM, JIT elevation| AzApp
    Entra -.->|PIM, JIT elevation| AzSQL

    AWSDataTier -.->|audit logs| GuardDuty
    AzSQL -.->|audit logs| Sentinel
```

## 2. Identity & Access Flow (Zero Trust)

```mermaid
sequenceDiagram
    participant User as Clinician/Engineer
    participant IdP as Entra ID / IAM Identity Center
    participant PIM as PIM / JIT Elevation
    participant Resource as PHI-Tier Resource
    participant Log as Audit Log (CloudTrail / Activity Log)

    User->>IdP: Authenticate (MFA + device posture check)
    IdP-->>User: Short-lived token (standard role, read-only)
    User->>PIM: Request elevation (justification required)
    PIM->>PIM: Evaluate policy (role eligibility, approval if required)
    PIM-->>User: Time-bound elevated token (e.g., 1 hour)
    User->>Resource: Access request with elevated token
    Resource->>Log: Record access (identity, scope, timestamp)
    Resource-->>User: Grant scoped access
    Note over PIM,Resource: Elevation auto-expires; standing access reverts to read-only
```

## 3. Data Classification & Flow

```mermaid
flowchart LR
    subgraph NonPHI["Non-PHI Data"]
        Marketing[Marketing content]
        AppMeta[App configuration/metadata]
    end

    subgraph PHI["PHI Data"]
        Records[Patient records / EHR]
        Telehealth[Telehealth session data]
        Billing[Billing linked to patient identity]
        AIInsights[AI model outputs derived from PHI]
    end

    NonPHI -->|Standard TLS, standard IAM| StandardTier[Standard Service Tier]
    PHI -->|TLS + KMS/Key Vault encryption, JIT-gated IAM, audit-logged| PHITier[PHI Service Tier - Private networking only]

    PHITier -->|No public endpoint| Blocked[❌ Public Internet]
    StandardTier -->|WAF-fronted, public endpoint OK| Internet[Public Internet]
```

## Notes

- All PHI-tier resources sit in private subnets/spokes with no public endpoint, consistent with ADR 0001 and ADR 0002.
- The AWS and Azure environments are architecturally symmetric (WAF → app tier → private data tier) so the same policy-as-code rules (Phase 2) can apply to both with minimal cloud-specific branching.
- Diagrams render directly in GitHub via Mermaid — no external tooling required to view them.
