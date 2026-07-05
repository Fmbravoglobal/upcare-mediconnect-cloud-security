variable "environment" {
  type = string
}

variable "alert_email" {
  description = "Email address (or SNS-subscribed distribution list) to receive high-severity findings"
  type        = string
}

resource "aws_guardduty_detector" "this" {
  enable = true

  datasources {
    s3_logs {
      enable = true # detects anomalous access to PHI document storage
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = {
    Project     = "upcare-mediconnect"
    Environment = var.environment
  }
}

resource "aws_securityhub_account" "this" {}

resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.4.0"
  depends_on    = [aws_securityhub_account.this]
}

resource "aws_securityhub_standards_subscription" "aws_fsbp" {
  standards_arn = "arn:aws:securityhub:::ruleset/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.this]
}

# --- SNS topic + subscription for high-severity finding alerts ---
resource "aws_sns_topic" "security_alerts" {
  name              = "upcare-${var.environment}-security-alerts"
  kms_master_key_id = "alias/aws/sns" # AWS-managed key acceptable here — topic carries alert metadata, not PHI

  tags = {
    Project     = "upcare-mediconnect"
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- EventBridge rule: route GuardDuty HIGH/CRITICAL findings to SNS ---
resource "aws_cloudwatch_event_rule" "guardduty_high_severity" {
  name        = "upcare-${var.environment}-guardduty-high-severity"
  description = "Routes GuardDuty findings with severity >= 7 (High/Critical) to the security alerts topic"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_high_severity.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}

output "detector_id" {
  value = aws_guardduty_detector.this.id
}

output "alerts_topic_arn" {
  value = aws_sns_topic.security_alerts.arn
}
