# main/debug.tf

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