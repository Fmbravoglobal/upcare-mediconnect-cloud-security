package terraform.security.no_public_storage

# Deny any AWS S3 bucket or Azure Storage Account / Blob Container that allows public access.
# Referenced control: HIPAA Technical Safeguards - Access Control; threat model "Information Disclosure".

import future.keywords.in
import future.keywords.contains

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_s3_bucket_public_access_block"
	resource.change.after.block_public_acls == false
	msg := sprintf("S3 bucket public access block must have block_public_acls=true: %s", [resource.address])
}

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_s3_bucket_public_access_block"
	resource.change.after.restrict_public_buckets == false
	msg := sprintf("S3 bucket public access block must have restrict_public_buckets=true: %s", [resource.address])
}

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "azurerm_storage_account"
	resource.change.after.public_network_access_enabled == true
	msg := sprintf("Azure storage account must not have public_network_access_enabled=true: %s", [resource.address])
}

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "azurerm_key_vault"
	resource.change.after.public_network_access_enabled == true
	msg := sprintf("Azure Key Vault must not have public_network_access_enabled=true: %s", [resource.address])
}

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_db_instance"
	resource.change.after.publicly_accessible == true
	msg := sprintf("RDS instance must not be publicly_accessible: %s", [resource.address])
}

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "azurerm_mssql_server"
	resource.change.after.public_network_access_enabled == true
	msg := sprintf("Azure SQL server must not have public_network_access_enabled=true: %s", [resource.address])
}
