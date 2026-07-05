terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Fill in via -backend-config at init time (bucket/key/region/dynamodb_table)
    # Remote state with locking — required so IaC state can't be silently tampered with (ADR 0001, threat model: Tampering)
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "upcare-mediconnect"
      ManagedBy = "terraform"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type = string
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "kms_admin_arns" {
  type = list(string)
}

variable "kms_user_arns" {
  type = list(string)
}

# TODO(Phase 2b): replace with module.compute.app_security_group_id once the
# ECS/EKS compute module is added. Kept as an explicit variable for now so this
# root module fails loudly (missing var) rather than silently misconfiguring
# the PHI database's ingress rule with an implicit/incorrect value.
variable "app_security_group_id" {
  type = string
}

module "vpc" {
  source      = "../modules/aws-vpc"
  environment = var.environment
  azs         = var.azs
}

module "phi_kms" {
  source         = "../modules/aws-kms"
  environment    = var.environment
  key_alias      = "phi-data"
  key_admin_arns = var.kms_admin_arns
  key_user_arns  = var.kms_user_arns
}

# NOTE: app_security_group_id below is a placeholder — wire to the actual app-tier
# security group once the compute module (ECS/EKS) is added. Left explicit rather
# than hidden so this root module fails loudly instead of silently misconfiguring
# the PHI database's ingress rule.
module "phi_database" {
  source                = "../modules/aws-rds-encrypted"
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  data_subnet_ids       = module.vpc.data_subnet_ids
  app_security_group_id = var.app_security_group_id # TODO: wire to compute module output once it exists
  kms_key_arn           = module.phi_kms.key_arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "phi_kms_key_arn" {
  value = module.phi_kms.key_arn
}
