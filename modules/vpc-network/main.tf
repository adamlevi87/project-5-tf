# Only allocate NATs based on nat_mode
locals {
  nat_gateway_count = (
    var.nat_mode == "real"       ? length(var.public_subnet_cidrs) :
    var.nat_mode == "single"     ? 1 :
    var.nat_mode == "endpoints"  ? 0 :
    0
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

# creation-loop, index based, from the subnet variable with the availability zone variable
resource "aws_subnet" "public" {
  count                  = length(var.public_subnet_cidrs)

  vpc_id                 = aws_vpc.main.id
  cidr_block             = var.public_subnet_cidrs[count.index]
  availability_zone      = var.availability_zones[count.index]

  tags = {
    Name    = "${var.project_tag}-public-subnet-${count.index}"
    Project = var.project_tag
    Environment = var.environment
  }
}

# creation-loop, index based, from the subnet variable with the availability zone variable
resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.project_tag}-private-subnet-${count.index}"
    Project     = var.project_tag
    Environment = var.environment
  }
}

# Public Traffic Routed via the IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name    = "${var.project_tag}-public-subnets-rt"
    Project = var.project_tag
    Environment = var.environment
  }
}

# Associate all public subnets with the public route
resource "aws_route_table_association" "public_subnets" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Creating Elastic IPs to be used in the NATs
resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"

  tags = {
    Name        = "${var.project_tag}-nat-eip-${count.index}"
    Project     = var.project_tag
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "this" {
  count         = local.nat_gateway_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.igw]

  tags = {
    Name        = "${var.project_tag}-nat-gw-${count.index}"
    Project     = var.project_tag
    Environment = var.environment
  }
}

resource "aws_route_table" "private" {
  count  = local.nat_gateway_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = {
    Name        = "${var.project_tag}-private-rt-${count.index}"
    Project     = var.project_tag
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private_subnets" {
  # this block will be skipped to avoid an error when nat_mode = endpoints
  count          = var.nat_mode == "endpoints" ? 0 : length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id

  # Route table logic: one-per-AZ for real, one shared for single
  # when ==real we will be using private[count.index] - meaning 1 route for each subnet
  # else, we will be using the one and only route_table.private[0]
  route_table_id = aws_route_table.private[
    var.nat_mode == "real" ? count.index : 0
  ].id
}