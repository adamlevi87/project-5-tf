# main/main.tf

data "aws_availability_zones" "available" {
    state = "available"
}

locals {
    availability_zones = slice(data.aws_availability_zones.available.names, 0, var.availability_zones_to_use)
}

output "az_debug" {
  value = local.availability_zones
}

module "vpc_network" {
    source = "../modules/vpc-network"
    
    vpc_cidr_block = var.vpc_cidr_block
    # Will be working with 3 Availability Zones
    availability_zones = local.availability_zones

    # Will be working with 1public & 1private subnets for each AZ
    public_subnet_cidrs = [
        for i in range(length(local.availability_zones)) : cidrsubnet(var.vpc_cidr_block, 8, 0 + i)
    ]

    # private index offset: 100,101,102,...
    private_subnet_cidrs = [
        for i in range(length(local.availability_zones)) : cidrsubnet(var.vpc_cidr_block, 8, 100 + i)
    ]

    environment = var.environment
    project_tag   = var.project_tag
}
