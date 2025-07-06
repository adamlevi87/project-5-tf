# environments/dev/terraform.tfvars

aws_region = "us-east-1"

# Primary infrastructure (always exists - houses the primary NAT)
primary_availability_zones = 1  # Always keep 1 AZ for primary NAT gateway

# Additional infrastructure (optional in single mode, required in real mode)
additional_availability_zones = 2  # Can be reduced in single mode without affecting primary NAT

# Network configuration
vpc_cidr_block = "10.0.0.0/16"
nat_mode = "single"  # Options: "single", "real", "endpoints"

# Project configuration
environment = "dev"
project_tag = "project-5"




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