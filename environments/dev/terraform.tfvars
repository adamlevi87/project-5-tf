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
rds_database_port       = 5432

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

# Configuration for secrets
secrets_config = {
    rds-password = {
        description        = "Database password for RDS instance"
        generate_password  = true
        password_length    = 16
        password_special   = true
        password_override_special = "!#$%&*()-_=+[]{}|;:,.<>?"
    }
    # Future secrets go here
}

ecr_repository_name = "project-5"
ecr_repositories_applications = ["backend","frontend"]

domain_name = "projects-devops.cfd"
subdomain_name = "project-5"

# EKS Cluster Configuration
eks_kubernetes_version = "1.33"

# Whitelist your host + temporary - for github - all IPs - EKS api access
# this is mainly for Github runners until we move onto a better method- maybe VPC endpoints? 
# github workflow that runs the TF apply uses kubernetes/helm modules which requires white listing the runners
eks_api_allowed_cidr_blocks    = ["85.64.239.117/32","0.0.0.0/0"]


argocd_allowed_cidr_blocks = ["85.64.239.117/32"]




# EKS Node Group Configuration (minimal for dev)
eks_node_instance_types   = ["t3.small"]  # Bare minimum instance type
eks_node_desired_capacity = 1             # Single node for dev
eks_node_max_capacity     = 3             # Allow scaling if needed
eks_node_min_capacity     = 1             # Keep at least one node

# EKS Logging Configuration (minimal retention for cost)
eks_log_retention_days = 7  # 1 week retention for dev environment

# ALB Configuration
alb_deletion_protection = false  # Allow easy deletion in dev environment

# backed service details
backend_service_namespace    = "default"
backend_service_account_name = "backend-sa"

github_org = "adamlevi87"
github_application_repo = "project-5-app"

eks_user_access_map = {
  adam_local = {
    username = "adam.local"
    groups   = ["system:masters"]
  }
  adam_login = {
    username = "adam-login"
    groups   = ["system:masters"]
  }
}

# ArgoCD
argocd_namespace         = "argocd"
argocd_helm_release_base_name = "argocd"
argocd_chart_version     = "8.2.3"
argocd_base_domain_name = "argocd"




# container_port = 3000
# task_cpu = 256
# task_memory = 512
# ecs_log_stream_prefix = "ecs"
# ecs_network_mode = "awsvpc"
# ecs_protocol = "tcp"
# ecs_requires_compatibilities = "FARGATE"

# container_name = "chatbot-ui-gpt4-playground"


# allow_destroy_hosted_zone = "true"