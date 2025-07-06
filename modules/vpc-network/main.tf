locals {
  # Get the first AZ for stable NAT placement
  primary_az = keys(var.public_subnet_cidrs)[0]
  
  # Create stable NAT configuration
  nat_gateway_config = var.nat_mode == "single" ? {
    primary = {
      az = local.primary_az
      cidr = var.public_subnet_cidrs[local.primary_az]
    }
  } : var.nat_mode == "real" ? {
    for az, cidr in var.public_subnet_cidrs : az => {
      az = az
      cidr = cidr
    }
  } : {}
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

resource "aws_subnet" "public" {
  for_each = var.public_subnet_cidrs
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key
  tags = {
    Name        = "${var.project_tag}-public-subnet-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
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

resource "aws_route_table" "public" {
  for_each = var.public_subnet_cidrs
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name        = "${var.project_tag}-public-rt-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public_subnets" {
  for_each = var.public_subnet_cidrs
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[each.key].id
}

# Stable NAT resources with fixed keys
resource "aws_eip" "nat" {
  for_each = local.nat_gateway_config
  domain   = "vpc"
  tags = {
    Name        = "${var.project_tag}-nat-eip-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "this" {
  for_each      = local.nat_gateway_config
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.value.az].id
  depends_on    = [aws_internet_gateway.igw]
  tags = {
    Name        = "${var.project_tag}-nat-gw-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
  }
}

resource "aws_route_table" "private" {
  for_each = var.nat_mode != "endpoints" ? var.private_subnet_cidrs : {}
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = (
      var.nat_mode == "real" && contains(keys(local.nat_gateway_config), each.key) ? 
        aws_nat_gateway.this[each.key].id :
      var.nat_mode == "single" ? 
        aws_nat_gateway.this["primary"].id :
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
  for_each = var.nat_mode != "endpoints" ? aws_subnet.private : {}
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}