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

output "ns_records_to_set" {
  value = module.route53.name_servers
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc_network.vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc_network.private_subnet_ids
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc_network.public_subnet_ids
}

output "nat_gateway_ids" {
  description = "Map of NAT gateway IDs by AZ"
  value       = module.vpc_network.nat_gateway_ids
}

# EKS outputs
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint of the EKS cluster"
  value       = module.eks.cluster_endpoint
}

# Database outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_endpoint
}

# S3 and SQS outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = module.s3_app_data.bucket_name
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = module.sqs.queue_url
}

# Route53 outputs
output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = module.route53.zone_id
}

output "route53_name_servers" {
  description = "Route53 name servers to configure at domain registrar"
  value       = module.route53.name_servers
}

# ACM Certificate
output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = module.acm.this_certificate_arn
}

# ECR Repository
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.ecr_repository_urls
}

# # ALB outputs
# output "alb_dns_name" {
#   description = "DNS name of the Application Load Balancer"
#   value       = module.alb.alb_dns_name
# }

# output "alb_zone_id" {
#   description = "Zone ID of the Application Load Balancer"
#   value       = module.alb.alb_zone_id
# }

# output "target_group_arns" {
#   description = "ARNs of the target groups"
#   value       = module.alb.target_group_arns
# }

# Application URL
output "application_url" {
  description = "URL to access the application"
  value       = "https://${var.subdomain_name}.${var.domain_name}"
}

# # ALB Target Groups (for AWS Load Balancer Controller)
# output "frontend_target_group_arn" {
#   description = "Frontend target group ARN"
#   value       = module.alb.target_group_arns["frontend"]
# }

# output "backend_target_group_arn" {
#   description = "Backend target group ARN"
#   value       = module.alb.target_group_arns["backend"]
# }

# AWS Region
output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

# Secrets Manager (for database password)
output "rds_password_secret_arn" {
  description = "ARN of RDS password secret in Secrets Manager"
  value       = module.secrets.secret_arns["rds-password"]
}