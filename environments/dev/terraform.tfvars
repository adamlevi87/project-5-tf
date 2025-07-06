environment = "dev"
aws_region = "us-east-1"
project_tag = "project-5"
vpc_cidr_block = "10.0.0.0/16"

# Core infrastructure (never change these in development)
core_availability_zones = 1  # Always keep 1 AZ for NAT gateway

# Optional infrastructure (safe to change)
optional_availability_zones = 2  # Can be reduced to 1 or 0 without affecting NAT


# Controls the method that will allow the private subnets to communicate with the outside
# Expected values:
# single = all Private subnets will use a single NAT, that will be placed on the first public subnet
# real = 3 NATs, one for each pub/private subnet (Per AZ)
# endpoints = will use VPC endpoints for specific servers (it means, limited access to the outside)
    nat_mode = "single"

#




# github_org = "adamlevi87"
# github_repo = "project-5"
# container_port = 3000
# task_cpu = 256
# task_memory = 512
# ecs_log_stream_prefix = "ecs"
# ecs_network_mode = "awsvpc"
# ecs_protocol = "tcp"
# ecs_requires_compatibilities = "FARGATE"
# ecr_repository_name = "chatbot-ui-gpt4-playground"
# container_name = "chatbot-ui-gpt4-playground"
# domain_name = "projects-devops.cfd"
# subdomain_name = "chatbot-ui-gpt4-playground"

# allow_destroy_hosted_zone = "true"