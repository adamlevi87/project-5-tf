
locals {
  # Only allocate NATs based on nat_mode
  nat_gateway_azs = (
    var.nat_mode == "real" ? var.public_subnet_cidrs :
    var.nat_mode == "single" ? {
      for az, pair in var.public_subnet_cidrs :
        az => pair
          if az == keys(var.public_subnet_cidrs)[0]
    } :
    var.nat_mode == "endpoints" ? {} :
    {} # default
  )
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_tag}-vpc"
    Project = var.project_tag
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_tag}-igw"
    Project = var.project_tag
    Environment = var.environment
  }
}

# creation-loop, using for-each- resources will be created as a map
resource "aws_subnet" "public" {
  for_each               = var.public_subnet_cidrs

  vpc_id                 = aws_vpc.main.id
  cidr_block             = each.value
  availability_zone      = each.key

  tags = {
    Name    = "${var.project_tag}-public-subnet-${each.key}"
    Project = var.project_tag
    Environment = var.environment
  }
}

# creation-loop, using for-each- resources will be created as a map
resource "aws_subnet" "private" {
  for_each                = var.private_subnet_cidrs

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

# Public Traffic Routed via the IGW, 1 route table per public subnet
resource "aws_route_table" "public" {
  for_each = var.public_subnet_cidrs

  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name    = "${var.project_tag}-public-subnets-rt-${each.key}"
    Project = var.project_tag
    Environment = var.environment
  }
}

# Associate all public subnets with the public route
resource "aws_route_table_association" "public_subnets" {
  for_each       = var.public_subnet_cidrs
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[each.key].id
}

# Creating Elastic IPs to be used in the NATs
resource "aws_eip" "nat" {
  for_each  = local.nat_gateway_azs
  domain    = "vpc"

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
  for_each  = local.nat_gateway_azs
  vpc_id    = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[each.key].id
  }

  tags = {
    Name        = "${var.project_tag}-private-subnets-rt-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private_subnets" {
  # loop over all private subnets - real&single mode will still run on 3 subnets
  for_each = (
    var.nat_mode == "real" ? aws_subnet.private : 
    var.nat_mode == "single" ? aws_subnet.private : 
    var.nat_mode == "endpoints" ? {} :
    {}
  )

  subnet_id = each.value.id

  # nat_mode controls how many NATs we have
  # so it also affects the private subnets routes to those NAT/s
  # in 'real' mode, each subnet will be routed to each NAT
  # in 'single' mode, all subnets will be routed to the first and only NAT
  # no routing in endpoints
  route_table_id = (
    var.nat_mode == "real" ? aws_route_table.private[each.key].id :
    var.nat_mode == "single" ? aws_route_table.private[keys(local.nat_gateway_azs)[0]].id :
    var.nat_mode == "endpoints" ? null :
    null
  )
}
