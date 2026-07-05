variable "environment" {
  type = string
}

variable "alb_arn" {
  description = "ARN of the ALB to associate the WAF web ACL with"
  type        = string
}

variable "rate_limit" {
  description = "Max requests per 5-minute period per IP before blocking (DoS mitigation)"
  type        = number
  default     = 2000
}

resource "aws_wafv2_web_acl" "this" {
  name        = "upcare-${var.environment}-waf"
  description = "Edge protection for UpCare MediConnect patient/clinician-facing services"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # AWS Managed Rules — common web exploits (OWASP Top 10 coverage)
  rule {
    name     = "AWS-ManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "commonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Known bad inputs (SQLi, etc.) — critical given PHI data tier behind this WAF
  rule {
    name     = "AWS-ManagedRulesSQLiRuleSet"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "sqliRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Rate-based rule — mitigates DoS against patient portal / telehealth entry points
  rule {
    name     = "RateLimitPerIP"
    priority = 3
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = var.rate_limit
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rateLimitPerIP"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "upcare${var.environment}waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Project     = "upcare-mediconnect"
    Environment = var.environment
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

output "web_acl_arn" {
  value = aws_wafv2_web_acl.this.arn
}
