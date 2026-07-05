package terraform.security.mandatory_tagging

# Deny resources missing required tags — needed for compliance tracking, cost
# attribution, and identifying PHI-bearing resources at a glance (DataClass tag).

import future.keywords.in
import future.keywords.contains

required_tags := {"Project", "Environment"}

taggable_types := {
	"aws_db_instance",
	"aws_s3_bucket",
	"aws_kms_key",
	"aws_vpc",
	"azurerm_mssql_server",
	"azurerm_key_vault",
	"azurerm_virtual_network",
}

deny contains msg if {
	some resource in input.resource_changes
	resource.type in taggable_types
	tags := object.get(resource.change.after, "tags", {})
	some required in required_tags
	not tags[required]
	msg := sprintf("%s is missing required tag '%s'", [resource.address, required])
}

# PHI-bearing resource types must carry an explicit DataClass=phi tag so
# reviewers and automated tooling can identify regulated data without
# inspecting the underlying schema.
phi_resource_types := {
	"aws_db_instance",
	"azurerm_mssql_server",
	"azurerm_mssql_database",
}

deny contains msg if {
	some resource in input.resource_changes
	resource.type in phi_resource_types
	tags := object.get(resource.change.after, "tags", {})
	tags.DataClass != "phi"
	msg := sprintf("%s handles PHI and must be tagged DataClass=phi", [resource.address])
}
