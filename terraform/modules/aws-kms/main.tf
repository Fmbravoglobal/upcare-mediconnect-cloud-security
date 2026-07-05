variable "environment" {
  type = string
}

variable "key_alias" {
  description = "Alias suffix for this KMS key (e.g., 'phi-data', 'app-secrets')"
  type        = string
}

variable "key_admin_arns" {
  description = "IAM ARNs allowed to administer this key (not necessarily use it for encrypt/decrypt)"
  type        = list(string)
}

variable "key_user_arns" {
  description = "IAM ARNs allowed to use this key for encrypt/decrypt operations"
  type        = list(string)
}

resource "aws_kms_key" "this" {
  description             = "UpCare MediConnect ${var.environment} - ${var.key_alias}"
  deletion_window_in_days = 30
  enable_key_rotation     = true # mandatory annual rotation — HIPAA encryption key management expectation

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccountFullAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::*:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowKeyAdministration"
        Effect    = "Allow"
        Principal = { AWS = var.key_admin_arns }
        Action = [
          "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
          "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
          "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource",
          "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"
        ]
        Resource = "*"
      },
      {
        Sid       = "AllowKeyUsage"
        Effect    = "Allow"
        Principal = { AWS = var.key_user_arns }
        Action = [
          "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
          "kms:GenerateDataKey*", "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Project     = "upcare-mediconnect"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "this" {
  name          = "alias/upcare-${var.environment}-${var.key_alias}"
  target_key_id = aws_kms_key.this.key_id
}

output "key_arn" {
  value = aws_kms_key.this.arn
}

output "key_id" {
  value = aws_kms_key.this.key_id
}
