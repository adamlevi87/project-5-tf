# main/main.tf

data "aws_availability_zones" "available" {
    state = "available"
}

locals {
    # Will be working with a variable that controls how many Availability Zones we will be using
    availability_zones = slice(data.aws_availability_zones.available.names, 0, var.availability_zones_to_use)
    # Will be working with 1public & 1private subnets for each AZ
    subnet_pairs = {
        for i, az in local.availability_zones :
        az => {
            public_cidr  = cidrsubnet(var.vpc_cidr_block, 8, 0 + i)
            private_cidr = cidrsubnet(var.vpc_cidr_block, 8, 100 + i)
        }
    }
}

output "az_debug" {
  value = local.availability_zones
}

module "vpc_network" {
    source = "../modules/vpc-network"
    
    vpc_cidr_block = var.vpc_cidr_block
    
    availability_zones = local.availability_zones
    public_subnet_cidrs = [
        for pair in local.subnet_pairs : pair.public_cidr
    ]

    private_subnet_cidrs = [
        for pair in local.subnet_pairs : pair.public_cidr
    ]

    environment = var.environment
    project_tag   = var.project_tag
}
