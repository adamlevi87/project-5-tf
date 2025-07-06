locals {
  # Get all AZs for reference
  all_azs = keys(var.public_subnet_cidrs)
  primary_az = local.all_azs[0]
  
  # Separate core from optional subnets
  core_public_cidrs = {
    (local.primary_az) = var.public_subnet_cidrs[local.primary_az]
  }
  
  optional_public_cidrs = {
    for az, cidr in var.public_subnet_cidrs : az => cidr
    if az != local.primary_az
  }
  
  # NAT gateway configuration based on mode
  nat_gateway_config = (
    var.nat_mode == "real" ? var.public_subnet_cidrs :
    var.nat_mode == "single" ? { (local.primary_az) = var.public_subnet_cidrs[local.primary_az] } :
    var.nat_mode == "endpoints" ? {} :
    {}
  )
  
  # Determine which subnets need NAT routes
  subnets_needing_nat = var.nat_mode != "endpoints" ? var.private_subnet_cidrs : {}
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name        = "${var.project_tag}-vpc"
    Project     = var.project_tag
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name        = "${var.project_tag}-igw"
    Project     = var.project_tag
    Environment = var.environment
  }
}

# Core public subnet (stable - always exists for NAT in single/real mode)
resource "aws_subnet" "public_core" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.core_public_cidrs[local.primary_az]
  availability_zone = local.primary_az
  tags = {
    Name        = "${var.project_tag}-public-subnet-core-${local.primary_az}"
    Project     = var.project_tag
    Environment = var.environment
    Type        = "core"
  }
}

# Optional public subnets (can be destroyed safely)
resource "aws_subnet" "public_optional" {
  for_each = local.optional_public_cidrs
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key
  tags = {
    Name        = "${var.project_tag}-public-subnet-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
    Type        = "optional"
  }
}

# All public subnets combined for reference
locals {
  all_public_subnets = merge(
    { (local.primary_az) = aws_subnet.public_core },
    aws_subnet.public_optional
  )
}

resource "aws_subnet" "private" {
  for_each = var.private_subnet_cidrs
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false
  tags = {
    Name        = "${var.project_tag}-private-subnet-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
  }
}

# Core public route table (stable)
resource "aws_route_table" "public_core" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name        = "${var.project_tag}-public-rt-core-${local.primary_az}"
    Project     = var.project_tag
    Environment = var.environment
    Type        = "core"
  }
}

# Optional public route tables
resource "aws_route_table" "public_optional" {
  for_each = local.optional_public_cidrs
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name        = "${var.project_tag}-public-rt-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
    Type        = "optional"
  }
}

# Core public route table association (stable)
resource "aws_route_table_association" "public_core" {
  subnet_id      = aws_subnet.public_core.id
  route_table_id = aws_route_table.public_core.id
}

# Optional public route table associations
resource "aws_route_table_association" "public_optional" {
  for_each = aws_subnet.public_optional
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_optional[each.key].id
}

# EIP for NAT gateways
resource "aws_eip" "nat" {
  for_each = local.nat_gateway_config
  domain   = "vpc"
  tags = {
    Name        = "${var.project_tag}-nat-eip-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
  }
}

# NAT gateways - supports all three modes
resource "aws_nat_gateway" "nat" {
  for_each      = local.nat_gateway_config
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = local.all_public_subnets[each.key].id
  depends_on    = [aws_internet_gateway.igw]
  tags = {
    Name        = "${var.project_tag}-nat-gw-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
  }
}

# Private route tables with proper NAT routing logic
resource "aws_route_table" "private" {
  for_each = local.subnets_needing_nat
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = (
      # REAL mode: each private subnet routes to NAT in same AZ
      var.nat_mode == "real" ? aws_nat_gateway.nat[each.key].id :
      # SINGLE mode: all private subnets route to the single NAT in primary AZ
      var.nat_mode == "single" ? aws_nat_gateway.nat[local.primary_az].id :
      # ENDPOINTS mode: no NAT routing (handled by condition above)
      null
    )
  }
  tags = {
    Name        = "${var.project_tag}-private-rt-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private_subnets" {
  for_each = local.subnets_needing_nat
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

# Outputs for reference
output "nat_mode" {
  value = var.nat_mode
  description = "Current NAT mode: real (3 NATs), single (1 NAT), or endpoints (no NATs)"
}

output "nat_gateway_ids" {
  value = {
    for k, v in aws_nat_gateway.nat : k => v.id
  }
  description = "Map of NAT gateway IDs by AZ"
}

output "public_subnets" {
  value = {
    for k, v in local.all_public_subnets : k => {
      id = v.id
      cidr = v.cidr_block
      az = v.availability_zone
      type = k == local.primary_az ? "core" : "optional"
    }
  }
  description = "All public subnets with their properties"
}