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

variable "phi_data_subnet_id" {
  type = string
}

variable "key_vault_key_id" {
  description = "Key Vault key ID used for Transparent Data Encryption (customer-managed key)"
  type        = string
}

variable "admin_login" {
  type      = string
  sensitive = true
}

variable "admin_password" {
  type      = string
  sensitive = true
}

resource "azurerm_mssql_server" "phi" {
  name                         = "upcare-${var.environment}-sql"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.admin_login
  administrator_login_password = var.admin_password

  public_network_access_enabled = false # no public endpoint — private endpoint only (ADR 0001/0002)
  minimum_tls_version           = "1.2"

  identity {
    type = "SystemAssigned" # required for customer-managed key access to Key Vault
  }

  tags = {
    Project     = "upcare-mediconnect"
    Environment = var.environment
    DataClass   = "phi"
  }
}

resource "azurerm_mssql_database" "ehr" {
  name      = "upcare-${var.environment}-ehr-db"
  server_id = azurerm_mssql_server.phi.id
  sku_name  = "GP_Gen5_4" # General Purpose — adjust per throughput needs

  # Transparent Data Encryption with customer-managed key (not service-managed default)
  transparent_data_encryption_enabled = true

  tags = {
    Project     = "upcare-mediconnect"
    Environment = var.environment
    DataClass   = "phi"
  }
}

resource "azurerm_mssql_server_transparent_data_encryption" "phi_cmk" {
  server_id        = azurerm_mssql_server.phi.id
  key_vault_key_id = var.key_vault_key_id
}

resource "azurerm_private_endpoint" "sql" {
  name                = "upcare-${var.environment}-sql-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.phi_data_subnet_id

  private_service_connection {
    name                           = "upcare-${var.environment}-sql-psc"
    private_connection_resource_id = azurerm_mssql_server.phi.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  tags = {
    Project     = "upcare-mediconnect"
    Environment = var.environment
  }
}

# Audit logging to satisfy HIPAA §164.312(b) — all queries against PHI logged
resource "azurerm_mssql_server_extended_auditing_policy" "phi" {
  server_id              = azurerm_mssql_server.phi.id
  storage_endpoint       = null # wire to a storage account output from a logging module in Phase 5
  retention_in_days      = 365
  log_monitoring_enabled = true
}

output "sql_server_id" {
  value = azurerm_mssql_server.phi.id
}

output "sql_database_id" {
  value = azurerm_mssql_database.ehr.id
}
