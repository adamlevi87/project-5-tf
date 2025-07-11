# main/main.tf
data "aws_availability_zones" "available" {
    state = "available"
}

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
  
  secrets = {
    # RDS database password - auto-generated
    rds-password = {
      description        = "Database password for RDS instance"
      generate_password  = true
      password_length    = 16
      password_special   = true
    }
    
    # Future secrets can be added here
    # api-key = {
    #   description        = "External API key"
    #   generate_password  = false
    #   secret_value       = var.external_api_key
    # }
  }
}

# main/main.tf - RDS Module Usage

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