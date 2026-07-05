package terraform.security.restrict_ingress

# Deny security groups / NSGs that allow unrestricted ingress (0.0.0.0/0) on
# sensitive ports, or unrestricted ingress on any port. Referenced control:
# ADR 0001 (least privilege), threat model "Elevation of Privilege" / "Information Disclosure".

import future.keywords.in
import future.keywords.contains

sensitive_ports := {22, 3389, 5432, 3306, 1433, 27017}

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_security_group"
	some rule in resource.change.after.ingress
	"0.0.0.0/0" in rule.cidr_blocks
	rule.from_port in sensitive_ports
	msg := sprintf("%s allows unrestricted ingress (0.0.0.0/0) on sensitive port %d", [resource.address, rule.from_port])
}

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_security_group"
	some rule in resource.change.after.ingress
	"0.0.0.0/0" in rule.cidr_blocks
	rule.from_port == 0
	rule.to_port == 0
	msg := sprintf("%s allows unrestricted ingress (0.0.0.0/0) on ALL ports", [resource.address])
}

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "azurerm_network_security_rule"
	resource.change.after.direction == "Inbound"
	resource.change.after.source_address_prefix == "*"
	resource.change.after.access == "Allow"
	msg := sprintf("%s allows unrestricted inbound access (source '*')", [resource.address])
}

# PHI data-tier security groups specifically must never have public ingress,
# regardless of port — data tier should only ever be reached from the app tier.
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_security_group"
	tags := object.get(resource.change.after, "tags", {})
	tags.DataClass == "phi"
	some rule in resource.change.after.ingress
	"0.0.0.0/0" in rule.cidr_blocks
	msg := sprintf("%s is a PHI-tier security group and must not allow any 0.0.0.0/0 ingress", [resource.address])
}
