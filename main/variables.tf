variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones_to_use" {
  description = "The number of Availability zones to use"
  type        = string
}

variable "environment" {
  description = "environment name for tagging resources"
  type        = string
}

variable "project_tag" {
  description = "Tag used to label resources"
  type        = string
}



# variable "github_org" {
#   description = "GitHub organization"
#   type        = string
# }

# variable "github_repo" {
#   description = "GitHub repository name"
#   type        = string
# }

# variable "ecr_repository_name" {
#   description = "ECR repository name"
#   type        = string
# }




# variable "task_cpu" {
#   description = "CPU units for ECS task"
#   type        = number
# }

# variable "task_memory" {
#   description = "Memory (MB) for ECS task"
#   type        = number
# }

# variable "container_name" {
#   type        = string
#   description = "Name of the container running in the ECS task definition"
# }

# variable "container_port" {
#   type        = number
#   description = "Port exposed by the container"
#   default     = 3000
# }

# variable "domain_name" {
#   type        = string
#   description = "The root domain to configure (e.g., yourdomain.com)"
# }

# variable "subdomain_name" {
#   type        = string
#   description = "The subdomain for the app (e.g., chatbot)"
# }



# # terraform apply -var="allow_destroy_hosted_zone=false"
# variable "allow_destroy_hosted_zone" {
#   description = "Set to true only when you want to allow destroying the hosted zone"
#   type        = bool
# }

# variable "ecs_log_stream_prefix" {
#   description = "ecs_log_stream_prefix setting for passing through the module & the application repo"
#   type        = string
# }

# variable "ecs_network_mode" {
#   description = "ecs_network_mode setting for passing through the module & the application repo"
#   type        = string
# }

# variable "ecs_protocol" {
#   description = "ecs_protocol setting for passing through the module & the application repo"
#   type        = string
# }

# variable "ecs_requires_compatibilities" {
#   description = "ecs_requires_compatibilities setting for passing through the module & the application repo"
#   type        = string
# }


# # Protected Variables secrtion using github repo secret (workflow)
# # (or passed through the cli on terraform commands)
# # example: terraform plan -var="github_token=YOURKEY" -var="aws_iam_openid_connect_provider_github_arn=ARN"
# variable "github_token" {
# description = "GitHub PAT with access to manage secrets"
# type        = string
# sensitive   = true
# }

# variable "aws_iam_openid_connect_provider_github_arn" {
#   type        = string
#   description = "github provider arn [created beforhand, using .requirements folder]"
#   sensitive   = true
# }


# variable "secrets_map" {
#   type        = map(string)
#   description = "Map of secret variable names to actual Secrets Manager secret names"
# }