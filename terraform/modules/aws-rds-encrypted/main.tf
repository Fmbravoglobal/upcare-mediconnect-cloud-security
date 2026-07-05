variable "environment" {
  type = string
}

variable "data_subnet_ids" {
  description = "Private data-tier subnet IDs (no route to internet)"
  type        = list(string)
}

variable "vpc_id" {
  type = string
}

variable "app_security_group_id" {
  description = "Security group ID of the app tier — the only tier allowed to reach the DB"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for storage encryption — must come from the aws-kms module, no default keys for PHI"
  type        = string
}

variable "engine" {
  type    = string
  default = "postgres"
}

variable "instance_class" {
  type    = string
  default = "db.t3.medium"
}

variable "multi_az" {
  description = "Multi-AZ for high availability — recommended true for any PHI production workload"
  type        = bool
  default     = true
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "upcare-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })

  tags = {
    Project     = "upcare-mediconnect"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_subnet_group" "this" {
  name       = "upcare-${var.environment}-data-subnet-group"
  subnet_ids = var.data_subnet_ids

  tags = {
    Project     = "upcare-mediconnect"
    Environment = var.environment
    DataClass   = "phi"
  }
}

resource "aws_security_group" "db" {
  name        = "upcare-${var.environment}-db-sg"
  description = "PHI database tier — inbound only from app tier, no public ingress"
  vpc_id      = var.vpc_id

  ingress {
    description     = "DB access from app tier only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]
  }

  egress {
    # checkov:skip=CKV_AWS_382: cidr_blocks is intentionally empty — this rule permits
    # no egress traffic at all. Checkov flags protocol "-1" regardless of an empty
    # cidr_blocks list; an empty list is not equivalent to 0.0.0.0/0.
    description = "No outbound required from data tier"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  tags = {
    Project     = "upcare-mediconnect"
    Environment = var.environment
    DataClass   = "phi"
  }
}

resource "aws_db_instance" "phi" {
  identifier     = "upcare-${var.environment}-ehr-db"
  engine         = var.engine
  instance_class = var.instance_class

  allocated_storage     = 100
  max_allocated_storage = 500 # storage autoscaling, avoids manual resize downtime

  # Encryption at rest — mandatory, non-default key (HIPAA Technical Safeguards)
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false # never — PHI tier has no public endpoint (ADR 0001/0002)

  multi_az = var.multi_az

  # Enhanced monitoring — CKV_AWS_118
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  # Auto minor version upgrades — CKV_AWS_226 — patches applied automatically during maintenance window
  auto_minor_version_upgrade = true

  # IAM database authentication — CKV_AWS_161 — allows IAM-based auth alongside password auth
  iam_database_authentication_enabled = true

  # Performance Insights, encrypted with the same customer-managed key — CKV_AWS_353
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.kms_key_arn
  performance_insights_retention_period = 7

  # Audit & durability
  backup_retention_period         = 35 # HIPAA-conscious retention window; adjust per BAA/org policy
  deletion_protection             = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  copy_tags_to_snapshot           = true
  skip_final_snapshot             = false
  final_snapshot_identifier       = "upcare-${var.environment}-ehr-db-final"

  # In-transit encryption enforced at the parameter-group level (force_ssl=1) — see variable note below
  parameter_group_name = aws_db_parameter_group.phi_ssl_enforced.name

  tags = {
    Project     = "upcare-mediconnect"
    Environment = var.environment
    DataClass   = "phi"
    ManagedBy   = "terraform"
  }
}

resource "aws_db_parameter_group" "phi_ssl_enforced" {
  name   = "upcare-${var.environment}-phi-ssl-enforced"
  family = "postgres15"

  parameter {
    name  = "rds.force_ssl"
    value = "1" # enforce TLS for all client connections — no plaintext DB traffic
  }

  tags = {
    Project     = "upcare-mediconnect"
    Environment = var.environment
  }
}

output "db_endpoint" {
  value     = aws_db_instance.phi.endpoint
  sensitive = true
}

output "db_security_group_id" {
  value = aws_security_group.db.id
}
