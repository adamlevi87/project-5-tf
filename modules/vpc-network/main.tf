
locals {
  # Dynamically select NAT placement AZ(s) based on nat_mode
  nat_gateway_azs = (
    var.nat_mode == "real" ? var.public_subnet_cidrs :
    var.nat_mode == "single" ? {
      for az in slice(keys(var.public_subnet_cidrs), 0, 1) :
      az => var.public_subnet_cidrs[az]
    } :
    var.nat_mode == "endpoints" ? {} :
    {}
  )
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

resource "aws_eip" "nat" {
  for_each = local.nat_gateway_azs
  domain   = "vpc"

  tags = {
    Name        = "${var.project_tag}-nat-eip-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "this" {
  for_each      = aws_eip.nat
  allocation_id = each.value.id
  subnet_id     = aws_subnet.public[each.key].id
  depends_on    = [aws_internet_gateway.igw]

  tags = {
    Name        = "${var.project_tag}-nat-gw-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
  }
}

resource "aws_route_table" "private" {
  for_each = (
    var.nat_mode == "real" || var.nat_mode == "single" ? var.private_subnet_cidrs :
    var.nat_mode == "endpoints" ? {} :
    {}
  )

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = (
      var.nat_mode == "real" ? aws_nat_gateway.this[each.key].id :
      var.nat_mode == "single" ? aws_nat_gateway.this[keys(local.nat_gateway_azs)[0]].id :
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
  for_each = (
    var.nat_mode == "real" || var.nat_mode == "single" ? aws_subnet.private :
    var.nat_mode == "endpoints" ? {} :
    {}
  )

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
