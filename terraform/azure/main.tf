terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }

  backend "azurerm" {
    # Fill in via -backend-config at init time (resource_group_name, storage_account_name, container_name, key)
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false # never auto-purge — PHI encryption keys require manual, audited deletion
    }
  }
}

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

variable "sql_admin_login" {
  type      = string
  sensitive = true
}

variable "sql_admin_password" {
  type      = string
  sensitive = true
}

module "network" {
  source               = "../modules/azure-vnet"
  environment          = var.environment
  location             = var.location
  resource_group_name  = var.resource_group_name
}

module "keyvault" {
  source              = "../modules/azure-keyvault"
  environment          = var.environment
  location             = var.location
  resource_group_name  = var.resource_group_name
  tenant_id            = var.tenant_id
  phi_data_subnet_id   = module.network.phi_data_subnet_id
}

module "sql" {
  source               = "../modules/azure-sql-encrypted"
  environment           = var.environment
  location              = var.location
  resource_group_name   = var.resource_group_name
  phi_data_subnet_id    = module.network.phi_data_subnet_id
  key_vault_key_id      = module.keyvault.phi_key_id
  admin_login            = var.sql_admin_login
  admin_password          = var.sql_admin_password
}

output "phi_app_subnet_id" {
  value = module.network.phi_app_subnet_id
}

output "key_vault_id" {
  value = module.keyvault.key_vault_id
}

output "sql_database_id" {
  value = module.sql.sql_database_id
}
