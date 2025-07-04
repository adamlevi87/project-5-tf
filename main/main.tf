# main/main.tf

data "aws_availability_zones" "available" {
    state = "available"
}

locals {
    # Will be working with a variable that controls how many Availability Zones we will be using
    availability_zones = slice(data.aws_availability_zones.available.names, 0, var.availability_zones_to_use)
    # Will be working with 1public & 1private subnets for each AZ
    # a Map of AZ with a nested map for public/private cidrs
    # Example:
    #     {
    #       "us-east-1a" = { public_cidr = "10.0.0.0/24", private_cidr = "10.0.100.0/24" },
    #       "us-east-1b" = { public_cidr = "10.0.1.0/24", private_cidr = "10.0.101.0/24" },
    #       ...
    #     }
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
    # Passes over a new map where AZ is the key and only its public cidr is the value
    public_subnet_cidrs = {
        for az, pair in local.subnet_pairs : az => pair.public_cidr
    }
    # Passes over a new map where AZ is the key and only its private cidr is the value
    private_subnet_cidrs = {
        for az, pair in local.subnet_pairs : az => pair.private_cidr
    }

    nat_mode = var.nat_mode
    
    environment = var.environment
    project_tag   = var.project_tag
}
