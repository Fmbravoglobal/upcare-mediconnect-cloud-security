variable "environment" {
  type = string
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "resource_group_name" {
  type = string
}

variable "hub_cidr" {
  type    = string
  default = "10.100.0.0/16"
}

variable "phi_spoke_cidr" {
  type    = string
  default = "10.101.0.0/16"
}

variable "nonphi_spoke_cidr" {
  type    = string
  default = "10.102.0.0/16"
}

locals {
  common_tags = {
    Project     = "upcare-mediconnect"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# --- Hub VNet: Azure Firewall lives here, all spoke egress routes through it (ADR 0002) ---
resource "azurerm_virtual_network" "hub" {
  name                = "upcare-${var.environment}-hub-vnet"
  address_space       = [var.hub_cidr]
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.common_tags
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet" # name is required exactly as-is by Azure
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_cidr, 8, 0)]
}

resource "azurerm_public_ip" "firewall" {
  name                = "upcare-${var.environment}-fw-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_firewall" "hub" {
  name                = "upcare-${var.environment}-fw"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  tags = local.common_tags
}

# --- Spoke: PHI services (EHR, telehealth, billing) — private endpoints only, no public exposure ---
resource "azurerm_virtual_network" "phi_spoke" {
  name                = "upcare-${var.environment}-phi-spoke-vnet"
  address_space       = [var.phi_spoke_cidr]
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = merge(local.common_tags, { DataClass = "phi" })
}

resource "azurerm_subnet" "phi_app" {
  name                 = "phi-app-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.phi_spoke.name
  address_prefixes     = [cidrsubnet(var.phi_spoke_cidr, 8, 0)]
}

resource "azurerm_subnet" "phi_data" {
  name                 = "phi-data-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.phi_spoke.name
  address_prefixes     = [cidrsubnet(var.phi_spoke_cidr, 8, 1)]

  private_endpoint_network_policies = "Enabled" # required for Private Endpoint use (Azure SQL, Key Vault)
}

# --- Spoke: non-PHI services (informational/marketing/internal tooling) ---
resource "azurerm_virtual_network" "nonphi_spoke" {
  name                = "upcare-${var.environment}-nonphi-spoke-vnet"
  address_space       = [var.nonphi_spoke_cidr]
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = merge(local.common_tags, { DataClass = "non-phi" })
}

resource "azurerm_subnet" "nonphi_app" {
  name                 = "nonphi-app-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.nonphi_spoke.name
  address_prefixes     = [cidrsubnet(var.nonphi_spoke_cidr, 8, 0)]
}

# --- Peering: both spokes peer to hub only (no direct spoke-to-spoke peering — forces hub inspection) ---
resource "azurerm_virtual_network_peering" "phi_to_hub" {
  name                      = "phi-to-hub"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.phi_spoke.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "hub_to_phi" {
  name                      = "hub-to-phi"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.phi_spoke.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "nonphi_to_hub" {
  name                      = "nonphi-to-hub"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.nonphi_spoke.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "hub_to_nonphi" {
  name                      = "hub-to-nonphi"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.nonphi_spoke.id
  allow_forwarded_traffic   = true
}

output "phi_app_subnet_id" {
  value = azurerm_subnet.phi_app.id
}

output "phi_data_subnet_id" {
  value = azurerm_subnet.phi_data.id
}

output "firewall_private_ip" {
  value = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}
