# main/main.tf
data "aws_availability_zones" "available" {
    state = "available"
}

locals {
    # Calculate total AZs needed
    total_azs = var.primary_availability_zones + var.additional_availability_zones
    
    # Get all available AZs
    all_availability_zones = slice(data.aws_availability_zones.available.names, 0, local.total_azs)
    
    # Separate primary and additional AZs
    primary_azs = slice(local.all_availability_zones, 0, var.primary_availability_zones)
    additional_azs = slice(local.all_availability_zones, var.primary_availability_zones, local.total_azs)
    
    # Calculate subnet pairs for all AZs
    all_subnet_pairs = {
        for i, az in local.all_availability_zones :
        az => {
            public_cidr  = cidrsubnet(var.vpc_cidr_block, 8, 0 + i)
            private_cidr = cidrsubnet(var.vpc_cidr_block, 8, 100 + i)
        }
    }
    
    # Separate primary and additional subnet pairs
    primary_subnet_pairs = {
        for az in local.primary_azs :
        az => local.all_subnet_pairs[az]
    }
    
    additional_subnet_pairs = {
        for az in local.additional_azs :
        az => local.all_subnet_pairs[az]
    }
}

# Debug outputs
output "az_debug" {
  value = {
    primary_azs = local.primary_azs
    additional_azs = local.additional_azs
    total_azs = local.total_azs
  }
}

output "subnet_debug" {
  value = {
    primary_subnets = local.primary_subnet_pairs
    additional_subnets = local.additional_subnet_pairs
  }
}

module "vpc_network" {
    source = "../modules/vpc-network"
   
    vpc_cidr_block = var.vpc_cidr_block
   
    # Pass separated primary and additional subnet CIDRs
    primary_public_subnet_cidrs = {
        for az, pair in local.primary_subnet_pairs : az => pair.public_cidr
    }
    
    additional_public_subnet_cidrs = {
        for az, pair in local.additional_subnet_pairs : az => pair.public_cidr
    }
    
    private_subnet_cidrs = {
        for az, pair in local.all_subnet_pairs : az => pair.private_cidr
    }
    
    nat_mode = var.nat_mode
    environment = var.environment
    project_tag = var.project_tag
}