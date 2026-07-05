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

variable "tenant_id" {
  type = string
}

variable "phi_data_subnet_id" {
  description = "Subnet ID for the private endpoint — Key Vault has no public network access"
  type        = string
}

resource "azurerm_key_vault" "this" {
  name                = "upcare-${var.environment}-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "premium" # HSM-backed keys for PHI encryption

  purge_protection_enabled   = true # required — prevents malicious/accidental permanent deletion of encryption keys
  soft_delete_retention_days = 90

  public_network_access_enabled = false # private endpoint only, no public network path (ADR 0001/0002)

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = {
    Project     = "upcare-mediconnect"
    Environment = var.environment
    DataClass   = "phi"
  }
}

resource "azurerm_private_endpoint" "kv" {
  name                = "upcare-${var.environment}-kv-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.phi_data_subnet_id

  private_service_connection {
    name                           = "upcare-${var.environment}-kv-psc"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  tags = {
    Project     = "upcare-mediconnect"
    Environment = var.environment
  }
}

# Encryption key for PHI data (Azure SQL TDE, storage encryption) — rotation enforced
resource "azurerm_key_vault_key" "phi_encryption" {
  name         = "upcare-${var.environment}-phi-key"
  key_vault_id = azurerm_key_vault.this.id
  key_type     = "RSA-HSM"
  key_size     = 2048

  key_opts = ["decrypt", "encrypt", "wrapKey", "unwrapKey"]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }
    expire_after         = "P1Y" # annual rotation
    notify_before_expiry = "P30D"
  }
}

output "key_vault_id" {
  value = azurerm_key_vault.this.id
}

output "phi_key_id" {
  value = azurerm_key_vault_key.phi_encryption.id
}
