variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
}

variable "tags" {
  description = "Common tags applied to all resources, including compliance tags"
  type        = map(string)
  default     = {}
}

locals {
  common_tags = merge(var.tags, {
    Project     = "upcare-mediconnect"
    ManagedBy   = "terraform"
    Environment = var.environment
    DataClass   = "mixed" # overridden to "phi" on data-tier resources
  })
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support    = true
  enable_dns_hostnames  = true

  tags = merge(local.common_tags, { Name = "upcare-${var.environment}-vpc" })
}

# Public subnets — ALB/WAF edge only. No app or data resources live here.
resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false # explicit: no auto-assigned public IPs, even in the public tier

  tags = merge(local.common_tags, { Name = "upcare-${var.environment}-public-${var.azs[count.index]}", Tier = "public" })
}

# Private app subnets — application/compute tier
resource "aws_subnet" "app" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.azs[count.index]

  tags = merge(local.common_tags, { Name = "upcare-${var.environment}-app-${var.azs[count.index]}", Tier = "app" })
}

# Private data subnets — PHI tier (RDS). No route to internet gateway.
resource "aws_subnet" "data" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone = var.azs[count.index]

  tags = merge(local.common_tags, { Name = "upcare-${var.environment}-data-${var.azs[count.index]}", Tier = "data", DataClass = "phi" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "upcare-${var.environment}-igw" })
}

resource "aws_eip" "nat" {
  # checkov:skip=CKV2_AWS_19: this EIP is attached to a NAT Gateway (see aws_nat_gateway.this
  # below), not directly to an EC2 instance. Checkov's EIP-attachment check only recognizes
  # direct EC2 association; NAT Gateway attachment is the intended, standard pattern here.
  count  = length(var.azs)
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "upcare-${var.environment}-nat-eip-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(local.common_tags, { Name = "upcare-${var.environment}-nat-${count.index}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(local.common_tags, { Name = "upcare-${var.environment}-public-rt" })
}

resource "aws_route_table" "app" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }
  tags = merge(local.common_tags, { Name = "upcare-${var.environment}-app-rt-${count.index}" })
}

# Data tier: NO default route to internet — private only, per Zero Trust/private-by-default principle (ADR 0001)
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "upcare-${var.environment}-data-rt" })
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

resource "aws_route_table_association" "data" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  value = aws_subnet.app[*].id
}

output "data_subnet_ids" {
  value = aws_subnet.data[*].id
}
