# modules/vpc-network/main.tf

locals {
  # Get primary AZ for stable references
  primary_az = keys(var.primary_public_subnet_cidrs)[0]
  
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

# Primary public subnets (always exist)
resource "aws_subnet" "public_primary" {
  for_each = var.primary_public_subnet_cidrs
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key
  tags = {
    Name        = "${var.project_tag}-public-subnet-primary-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
    Type        = "primary"
  }
}

# Additional public subnets (additional AZs)
resource "aws_subnet" "public_additional" {
  for_each = var.additional_public_subnet_cidrs
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key
  tags = {
    Name        = "${var.project_tag}-public-subnet-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
    Type        = "additional"
  }
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

# Primary public route tables
resource "aws_route_table" "public_primary" {
  for_each = var.primary_public_subnet_cidrs
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name        = "${var.project_tag}-public-rt-primary-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
    Type        = "primary"
  }
}

# Additional public route tables
resource "aws_route_table" "public_additional" {
  for_each = var.additional_public_subnet_cidrs
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name        = "${var.project_tag}-public-rt-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
    Type        = "additional"
  }
}

# Primary public route table associations
resource "aws_route_table_association" "public_primary" {
  for_each = aws_subnet.public_primary
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_primary[each.key].id
}

# Additional public route table associations
resource "aws_route_table_association" "public_additional" {
  for_each = aws_subnet.public_additional
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_additional[each.key].id
}

# PRIMARY NAT GATEWAY (always created unless endpoints mode)
resource "aws_eip" "nat_primary" {
  count  = var.nat_mode != "endpoints" ? 1 : 0
  domain = "vpc"
  tags = {
    Name        = "${var.project_tag}-nat-eip-primary"
    Project     = var.project_tag
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "nat_primary" {
  count         = var.nat_mode != "endpoints" ? 1 : 0
  allocation_id = aws_eip.nat_primary[0].id
  subnet_id     = aws_subnet.public_primary[local.primary_az].id
  depends_on    = [aws_internet_gateway.igw]
  tags = {
    Name        = "${var.project_tag}-nat-gw-primary"
    Project     = var.project_tag
    Environment = var.environment
  }
}

# ADDITIONAL NAT GATEWAYS (only created in real mode)
resource "aws_eip" "nat_additional" {
  for_each = var.nat_mode == "real" ? var.additional_public_subnet_cidrs : {}
  domain   = "vpc"
  tags = {
    Name        = "${var.project_tag}-nat-eip-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "nat_additional" {
  for_each      = var.nat_mode == "real" ? var.additional_public_subnet_cidrs : {}
  allocation_id = aws_eip.nat_additional[each.key].id
  subnet_id     = aws_subnet.public_additional[each.key].id
  depends_on    = [aws_internet_gateway.igw]
  tags = {
    Name        = "${var.project_tag}-nat-gw-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
  }
}

# Private route tables with NAT routing
resource "aws_route_table" "private" {
  for_each = local.subnets_needing_nat
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = (
      # SINGLE mode: all private subnets route to primary NAT
      var.nat_mode == "single" ? aws_nat_gateway.nat_primary[0].id :
      # REAL mode: route to corresponding NAT based on AZ
      var.nat_mode == "real" ? (
        # If this AZ has an additional NAT, use it; otherwise use primary
        contains(keys(aws_nat_gateway.nat_additional), each.key) ? 
          aws_nat_gateway.nat_additional[each.key].id : 
          aws_nat_gateway.nat_primary[0].id
      ) :
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
  description = "Current NAT mode: single (primary NAT only), real (NAT per AZ), or endpoints (no NATs)"
}

output "nat_gateway_ids" {
  value = merge(
    var.nat_mode != "endpoints" ? { (local.primary_az) = aws_nat_gateway.nat_primary[0].id } : {},
    { for k, v in aws_nat_gateway.nat_additional : k => v.id }
  )
  description = "Map of NAT gateway IDs by AZ"
}

output "public_subnets" {
  value = {
    primary = {
      for k, v in aws_subnet.public_primary : k => {
        id = v.id
        cidr = v.cidr_block
        az = v.availability_zone
      }
    }
    additional = {
      for k, v in aws_subnet.public_additional : k => {
        id = v.id
        cidr = v.cidr_block
        az = v.availability_zone
      }
    }
  }
  description = "All public subnets organized by type"
}