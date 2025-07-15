# main/main.tf
# 0002

data "aws_availability_zones" "available" {
    state = "available"
}

module "vpc_network" {
    source = "../modules/vpc-network"
   
    project_tag   = var.project_tag
    environment   = var.environment

    vpc_cidr_block = var.vpc_cidr_block
    nat_mode = var.nat_mode
   
    # Pass separated primary and additional subnet CIDRs
    # Primary Public
    primary_public_subnet_cidrs = {
        for az, pair in local.primary_subnet_pairs : az => pair.public_cidr
    }
    # Additional Public
    additional_public_subnet_cidrs = {
        for az, pair in local.additional_subnet_pairs : az => pair.public_cidr
    }
    # Private - all subnets
    private_subnet_cidrs = local.private_subnet_cidrs
}

module "s3_app_data" {
  source = "../modules/s3"

  project_tag   = var.project_tag
  environment   = var.environment
  
  # Lifecycle configuration
  enable_lifecycle_policy = true
  data_retention_days     = var.environment == "prod" ? 0 : 365  # Keep prod data forever, dev/staging for 1 year

  # Allow force destroy for non-prod environments
  force_destroy = var.environment != "prod"
}

module "sqs" {
  source = "../modules/sqs"

  project_tag = var.project_tag
  environment = var.environment
  
  # Queue configuration
  queue_name                = "app-messages"
  visibility_timeout_seconds = 60  # Give lambda 60 seconds to process
  receive_wait_time_seconds  = 20  # Enable long polling
  
  # Dead letter queue
  enable_dlq        = true
  max_receive_count = 3  # Try 3 times before moving to DLQ
  
  # Retention settings
  message_retention_seconds     = var.environment == "prod" ? 1209600 : 604800  # 14 days prod, 7 days dev/staging
  dlq_message_retention_seconds = 1209600  # Keep failed messages for 14 days
}

module "lambda" {
  source = "../modules/lambda"

  project_tag = var.project_tag
  environment = var.environment
  
  # Lambda configuration
  function_name     = "message-processor"
  lambda_source_dir = "./lambda-code"  # Module will auto-run npm install here
  handler           = "index.handler"
  runtime           = "nodejs18.x"
  timeout           = 60
  memory_size       = 256
  
  # SQS integration (from SQS module)
  sqs_queue_arn          = module.sqs.queue_arn
  sqs_lambda_policy_arn  = module.sqs.lambda_sqs_policy_arn
  
  # S3 integration (from S3 module)
  s3_bucket_name        = module.s3_app_data.bucket_name
  s3_lambda_policy_arn  = module.s3_app_data.lambda_s3_policy_arn
  
  # Event source mapping configuration
  batch_size                         = 1    # Process one message at a time
  maximum_batching_window_in_seconds = 5    # Wait max 5 seconds before invoking
  maximum_concurrency                = 10   # Max 10 concurrent executions
  
  # Logging
  log_retention_days = var.environment == "prod" ? 30 : 14
  
  # Custom environment variables
  environment_variables = {
    NODE_ENV = var.environment
    DEBUG    = var.environment == "dev" ? "true" : "false"
  }
}

# Creates secrets by generating a password or inserting a value
module "secrets" {
  source = "../modules/secrets-manager"

  project_tag = var.project_tag
  environment = var.environment
  
  secrets_config = var.secrets_config
}

module "rds" {
  source = "../modules/rds"

  project_tag = var.project_tag
  environment = var.environment
  
  # Secrets Manager integration
  db_password_secret_arn = module.secrets.secret_arns["rds-password"]
  
  # Networking (from VPC module)
  vpc_id             = module.vpc_network.vpc_id
  private_subnet_ids = module.vpc_network.private_subnet_ids
  allowed_cidr_blocks = values(local.private_subnet_cidrs) # Allow access from entire VPC
  
  # Database configuration
  postgres_version    = var.rds_postgres_version
  instance_class      = var.rds_instance_class
  database_name       = var.rds_database_name
  database_username   = var.rds_database_username
  
  # Storage
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_type          = var.rds_storage_type
  
  # Backup and maintenance
  backup_retention_period = var.rds_backup_retention_period
  backup_window          = var.rds_backup_window
  maintenance_window     = var.rds_maintenance_window
  
  # Protection settings (controlled by environment)
  deletion_protection = var.rds_deletion_protection
  skip_final_snapshot = var.rds_skip_final_snapshot
  
  # Monitoring
  enable_performance_insights = var.rds_enable_performance_insights
  monitoring_interval         = var.rds_monitoring_interval

  # Add this line at the end
  depends_on = [module.secrets]
}

module "ecr" {
  source = "../modules/ecr"

  environment = var.environment
  project_tag  = var.project_tag
  
  name = var.ecr_repository_name
}

module "route53" {
  source       = "../modules/route53"

  project_tag  = var.project_tag
  environment  = var.environment
  
  domain_name    = var.domain_name
  subdomain_name = var.subdomain_name
}

module "acm" {
  source           = "../modules/acm"

  project_tag      = var.project_tag
  environment      = var.environment

  cert_domain_name  = "${var.subdomain_name}.${var.domain_name}"
  route53_zone_id  = module.route53.zone_id
  route53_depends_on = module.route53.zone_id   # this is just to create a dependency chain
}

module "eks" {
  source = "../modules/eks"

  project_tag = var.project_tag
  environment = var.environment

  # Cluster configuration
  cluster_name        = "${var.project_tag}-${var.environment}-cluster"
  kubernetes_version  = var.eks_kubernetes_version
  
  # Networking (from VPC module)
  vpc_id               = module.vpc_network.vpc_id
  private_subnet_ids   = module.vpc_network.private_subnet_ids
  allowed_cidr_blocks  = [var.kubectl_access_cidr]  # Your host IP
  
  # Node group configuration
  node_group_instance_types   = var.eks_node_instance_types
  node_group_desired_capacity = var.eks_node_desired_capacity
  node_group_max_capacity     = var.eks_node_max_capacity
  node_group_min_capacity     = var.eks_node_min_capacity
  
  # Logging
  cluster_log_retention_days = var.eks_log_retention_days
}

module "external_dns" {
  source = "../modules/external-dns"

  project_tag        = var.project_tag
  environment        = var.environment

  domain_filter      = var.domain_name
  txt_owner_id       = module.route53.zone_id
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = aws_eks_cluster.main.identity[0].oidc[0].issuer
}
