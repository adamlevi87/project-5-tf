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

# RDS Configuration
rds_postgres_version    = "16.9"
rds_instance_class      = "db.t3.micro"        # Smallest/cheapest option
rds_database_name       = "myapp_db"           # Match your local postgres
rds_database_username   = "myapp"              # Match your local postgres

# Storage (minimal cost)
rds_allocated_storage     = 20      # AWS minimum for PostgreSQL
rds_max_allocated_storage = 100     # Allow some autoscaling growth
rds_storage_type          = "gp2"   # Cheapest storage option

# Backup and maintenance (minimal)
rds_backup_retention_period = 1                    # 1 day minimum for dev
rds_backup_window          = "03:00-04:00"         # Low traffic time UTC
rds_maintenance_window     = "sun:04:00-sun:05:00" # Sunday early morning UTC

# Protection and snapshot settings
rds_deletion_protection = false  # Allow easy deletion for dev environment
# skip_final_snapshot options:
# true  = No final snapshot when destroying (faster, no storage costs)
# false = Create final snapshot when destroying (data protection, costs money to store)
rds_skip_final_snapshot = true   # No final snapshot for dev environment

# Monitoring (minimal to save costs)
rds_enable_performance_insights = false  # Disable to save money
rds_monitoring_interval         = 0      # 0 = disabled, saves costs


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