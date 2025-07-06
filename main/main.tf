# main/main.tf
data "aws_availability_zones" "available" {
    state = "available"
}

locals {
    # Calculate total AZs needed
    total_azs = var.core_availability_zones + var.optional_availability_zones
    
    # Get all available AZs
    all_availability_zones = slice(data.aws_availability_zones.available.names, 0, local.total_azs)
    
    # Separate core and optional AZs
    core_azs = slice(local.all_availability_zones, 0, var.core_availability_zones)
    optional_azs = slice(local.all_availability_zones, var.core_availability_zones, local.total_azs)
    
    # Calculate subnet pairs for all AZs
    all_subnet_pairs = {
        for i, az in local.all_availability_zones :
        az => {
            public_cidr  = cidrsubnet(var.vpc_cidr_block, 8, 0 + i)
            private_cidr = cidrsubnet(var.vpc_cidr_block, 8, 100 + i)
        }
    }
    
    # Separate core and optional subnet pairs
    core_subnet_pairs = {
        for az in local.core_azs :
        az => local.all_subnet_pairs[az]
    }
    
    optional_subnet_pairs = {
        for az in local.optional_azs :
        az => local.all_subnet_pairs[az]
    }
}

# Debug outputs
output "az_debug" {
  value = {
    core_azs = local.core_azs
    optional_azs = local.optional_azs
    total_azs = local.total_azs
  }
}

output "subnet_debug" {
  value = {
    core_subnets = local.core_subnet_pairs
    optional_subnets = local.optional_subnet_pairs
  }
}

module "vpc_network" {
    source = "../modules/vpc-network"
   
    vpc_cidr_block = var.vpc_cidr_block
   
    # Pass separated core and optional subnet CIDRs
    core_public_subnet_cidrs = {
        for az, pair in local.core_subnet_pairs : az => pair.public_cidr
    }
    
    optional_public_subnet_cidrs = {
        for az, pair in local.optional_subnet_pairs : az => pair.public_cidr
    }
    
    private_subnet_cidrs = {
        for az, pair in local.all_subnet_pairs : az => pair.private_cidr
    }
    
    nat_mode = var.nat_mode
    environment = var.environment
    project_tag = var.project_tag
}