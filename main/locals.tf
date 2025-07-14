# main/locals.tf

locals {
    # Calculate total AZs needed
    total_azs = var.primary_availability_zones + var.additional_availability_zones
    
    # Get all available AZs
    # from [0] to [total_azs (not included, meaning -1)]
    # a list of all avaiability zones starting from the first ([0]) till the # of total azs - [3] not including [3]
    # meaning a list of [0] [1] [2] - so 3 AZs
    all_availability_zones = slice(data.aws_availability_zones.available.names, 0, local.total_azs)
    
    # Separate primary and additional AZs
    # [0] to [primary_availability_zones  - normally equals 1] so it will return a single AZ name
    primary_azs = slice(local.all_availability_zones, 0, var.primary_availability_zones)
    # going over the list again, slicing it from [1] to [total azs]  which will result in 2 AZ names
    additional_azs = slice(local.all_availability_zones, var.primary_availability_zones, local.total_azs)
    
    # Calculate subnet pairs for all AZs
    # Creation of a map , with a nested map
    # loop over all the availability zones one by one
    # create a map with a key that gets its value from the all_availability_zones list (meaning the AZ names)
    # and the value of: a nested map{
    #   public_cidr & private_cidr as keys
    #   values as the creation is a subnet cidr, for example 10.0.1.0/24
    # }
    all_subnet_pairs = {
        for i, az in local.all_availability_zones :
        az => {
            public_cidr  = cidrsubnet(var.vpc_cidr_block, 8, 0 + i)
            private_cidr = cidrsubnet(var.vpc_cidr_block, 8, 100 + i)
        }
    }
    
    # Separate primary and additional subnet pairs
    # Creation of a map for the primary AZ , that holds the AZ name and the subnet pairs (public & private)
    primary_subnet_pairs = {
        for az in local.primary_azs :
        az => local.all_subnet_pairs[az]
    }
    # Creation of a map for the additional AZs , that holds the AZ names and the subnet pairs (public & private)
    additional_subnet_pairs = {
        for az in local.additional_azs :
        az => local.all_subnet_pairs[az]
    }

    # Private - all subnets
    private_subnet_cidrs = {
        for az, pair in local.all_subnet_pairs : az => pair.private_cidr
    }
}