variable "environment" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "backend_host" {
  description = "FQDN of the backend origin (App Service / AKS ingress)"
  type        = string
}

variable "rate_limit_requests" {
  description = "Requests per minute per client IP before blocking"
  type        = number
  default     = 300
}

resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = "upcare-${var.environment}-afd"
  resource_group_name = var.resource_group_name
  sku_name            = "Premium_AzureFrontDoor" # Premium tier required for WAF managed rule sets

  tags = {
    Project     = "upcare-mediconnect"
    Environment = var.environment
  }
}

resource "azurerm_cdn_frontdoor_firewall_policy" "this" {
  name                = "upcareWaf${var.environment}"
  resource_group_name = var.resource_group_name
  sku_name            = azurerm_cdn_frontdoor_profile.this.sku_name
  mode                = "Prevention" # block, not just log — PHI-adjacent edge

  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Block"
  }

  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.0"
    action  = "Block"
  }

  custom_rule {
    name                           = "RateLimitPerIP"
    enabled                        = true
    priority                       = 1
    type                           = "RateLimitRule"
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = var.rate_limit_requests
    action                         = "Block"

    match_condition {
      match_variable = "RequestUri"
      operator       = "Any"
      match_values   = ["/*"]
    }
  }

  tags = {
    Project     = "upcare-mediconnect"
    Environment = var.environment
  }
}

resource "azurerm_cdn_frontdoor_endpoint" "this" {
  name                     = "upcare-${var.environment}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
}

resource "azurerm_cdn_frontdoor_origin_group" "this" {
  name                     = "upcare-${var.environment}-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  health_probe {
    path                = "/health"
    protocol            = "Https"
    interval_in_seconds = 30
  }

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "this" {
  name                           = "upcare-${var.environment}-origin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.this.id
  host_name                      = var.backend_host
  origin_host_header             = var.backend_host
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_security_policy" "this" {
  name                     = "upcare-${var.environment}-security-policy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.this.id
      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.this.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}

output "frontdoor_endpoint_hostname" {
  value = azurerm_cdn_frontdoor_endpoint.this.host_name
}
