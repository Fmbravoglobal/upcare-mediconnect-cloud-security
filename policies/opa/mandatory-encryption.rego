package terraform.security.mandatory_encryption

# Deny any storage/database resource that is not encrypted with a customer-managed key.
# Referenced control: HIPAA Technical Safeguards - Encryption; ADR 0001 (encrypted at rest and in transit).

import future.keywords.in
import future.keywords.contains

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_db_instance"
	resource.change.after.storage_encrypted != true
	msg := sprintf("RDS instance must have storage_encrypted=true: %s", [resource.address])
}

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_db_instance"
	not resource.change.after.kms_key_id
	msg := sprintf("RDS instance must specify a customer-managed kms_key_id (no default AWS-managed key for PHI): %s", [resource.address])
}

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_s3_bucket"
	not resource.change.after.server_side_encryption_configuration
	msg := sprintf("S3 bucket must have server_side_encryption_configuration set: %s", [resource.address])
}

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "azurerm_mssql_database"
	resource.change.after.transparent_data_encryption_enabled != true
	msg := sprintf("Azure SQL database must have transparent_data_encryption_enabled=true: %s", [resource.address])
}

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "azurerm_mssql_server"
	resource.change.after.minimum_tls_version != "1.2"
	msg := sprintf("Azure SQL server must enforce minimum_tls_version=1.2: %s", [resource.address])
}

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_kms_key"
	resource.change.after.enable_key_rotation != true
	msg := sprintf("KMS key must have enable_key_rotation=true: %s", [resource.address])
}
