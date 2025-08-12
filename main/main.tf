# main/main.tf

# Generate passwords
resource "random_password" "generated_passwords" {
    for_each = {
        for name, config in var.secrets_config : name => config
        if config.generate_password == true
    }
    
    length  = each.value.password_length
    special = each.value.password_special

    override_special = each.value.password_override_special != "" ? each.value.password_override_special : null
    
    # lifecycle {
    #   ignore_changes = [result]
    # }
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

module "secrets_rds_password" {
  source = "../modules/secrets-manager"

  project_tag = var.project_tag
  environment = var.environment
  
  secrets_config_with_passwords = local.secrets_config_with_passwords
  app_secrets_config            = {}
}

module "secrets_app_envs" {
  source = "../modules/secrets-manager"

  project_tag = var.project_tag
  environment = var.environment
  
  secrets_config_with_passwords = {}
  app_secrets_config            = local.app_secrets_config
  
  depends_on = [module.secrets_rds_password]
}

module "rds" {
  source = "../modules/rds"

  project_tag = var.project_tag
  environment = var.environment
  
  # Secrets Manager integration
  db_password_secret_arn = module.secrets_rds_password.secret_arns["rds-password"]
  
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
  depends_on = [module.secrets_rds_password]
}

module "ecr" {
  source = "../modules/ecr"

  environment = var.environment
  project_tag  = var.project_tag
  
  ecr_repository_name = var.ecr_repository_name
  ecr_repositories_applications = var.ecr_repositories_applications
}

module "route53" {
  source       = "../modules/route53"

  project_tag  = var.project_tag
  environment  = var.environment
  
  domain_name    = var.domain_name
  subdomain_name = var.subdomain_name

  # alb_dns_name = 1
  # alb_zone_id = 1
}

module "acm" {
  source           = "../modules/acm"

  project_tag      = var.project_tag
  environment      = var.environment

  cert_domain_name  = "*.${var.subdomain_name}.${var.domain_name}"
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
  private_subnet_ids   = module.vpc_network.private_subnet_ids
  eks_api_allowed_cidr_blocks  = var.eks_api_allowed_cidr_blocks
  vpc_id = module.vpc_network.vpc_id
  
  # Node group configuration
  node_group_instance_types   = var.eks_node_instance_types
  node_group_desired_capacity = var.eks_node_desired_capacity
  node_group_max_capacity     = var.eks_node_max_capacity
  node_group_min_capacity     = var.eks_node_min_capacity
  
  # Logging
  cluster_enabled_log_types = var.cluster_enabled_log_types
  cluster_log_retention_days = var.eks_log_retention_days

  # ECR for nodegroup permissions
  ecr_repository_arns = module.ecr.ecr_repository_arns
}

module "external_dns" {
  source = "../modules/helm/external-dns"

  project_tag        = var.project_tag
  environment        = var.environment

  service_account_name = "external-dns-${var.environment}-service-account"
  release_name         = "external-dns-${var.environment}"
  namespace            = "kube-system"
  domain_filter      = var.domain_name
  txt_owner_id       = "externaldns-${var.project_tag}-${var.environment}"
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.cluster_oidc_issuer_url
  zone_type = "public"

  lbc_webhook_ready = module.aws_load_balancer_controller.webhook_ready
  depends_on = [module.eks]
}

module "cluster_autoscaler" {
  source = "../modules/helm/cluster-autoscaler"

  project_tag        = var.project_tag
  environment        = var.environment

  service_account_name = "cluster-autoscaler-${var.environment}-service-account"
  release_name         = "cluster-autoscaler"
  namespace            = "kube-system"
  cluster_name       = module.eks.cluster_name
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.cluster_oidc_issuer_url
  lbc_webhook_ready = module.aws_load_balancer_controller.webhook_ready
  depends_on = [module.eks]
}

module "backend" {
  source       = "../modules/apps/backend"

  project_tag        = var.project_tag
  environment        = var.environment

  vpc_id = module.vpc_network.vpc_id

  #cluster_name              = module.eks.cluster_name
  oidc_provider_arn         = module.eks.oidc_provider_arn
  oidc_provider_url         = module.eks.cluster_oidc_issuer_url
  namespace                 = var.backend_service_namespace
  service_account_name      = var.backend_service_account_name
  s3_bucket_arn             = module.s3_app_data.bucket_arn
  sqs_queue_arn             = module.sqs.queue_arn
  node_group_security_group = module.eks.node_group_security_group_id

  secret_arn = module.secrets_app_envs.app_secrets_arns["${var.backend_aws_secret_key}"]

  depends_on = [module.eks,module.secrets_app_envs]
}

module "frontend" {
  source       = "../modules/apps/frontend"

  project_tag        = var.project_tag
  environment        = var.environment

  vpc_id = module.vpc_network.vpc_id

  #cluster_name              = module.eks.cluster_name
  oidc_provider_arn         = module.eks.oidc_provider_arn
  oidc_provider_url         = module.eks.cluster_oidc_issuer_url
  namespace                 = var.frontend_service_namespace
  service_account_name      = var.frontend_service_account_name
  node_group_security_group = module.eks.node_group_security_group_id

  secret_arn = module.secrets_app_envs.app_secrets_arns["${var.frontend_aws_secret_key}"]

  depends_on = [module.eks, module.secrets_app_envs]
}

module "github_oidc" {
  source = "../modules/iam-github-oidc"

  project_tag        = var.project_tag
  environment        = var.environment

  github_org         = var.github_org
  github_repo        = var.github_application_repo
  aws_iam_openid_connect_provider_github_arn = var.aws_iam_openid_connect_provider_github_arn
}

module "github_repo_secrets" {
  source = "../modules/github-repo-secrets"
  
  repository_name = "${var.github_application_repo}"
  environment = var.environment

  github_variables = {
    AWS_REGION = "${var.aws_region}"
  }

  # every value which comes from an output requires SHA generation
  github_secrets = {
    AWS_ROLE_TO_ASSUME = "${module.github_oidc.github_actions_role_arn}"
    # ECR
    ECR_REPOSITORY_BACKEND  = "${module.ecr.ecr_repository_urls[var.ecr_repositories_applications[0]]}"
    ECR_REPOSITORY_FRONTEND = "${module.ecr.ecr_repository_urls[var.ecr_repositories_applications[1]]}"
    
    # Inject backend-specific values
    # SERVICE_NAME_BACKEND   = "${var.backend_service_account_name}"

    # Inject frontend-specific values
    #ECR_REPOSITORY_FRONTEND = "${module.ecr.repository_urls["frontend"]}"
    #SERVICE_NAME_FRONTEND   = module.frontend.service_name

    # Shared values (if needed in CI workflows)
    # CLUSTER_NAME    = "${module.eks.cluster_name}"
    # DB_HOST         = "${module.rds.db_instance_address}"
    # DB_NAME         = "${var.rds_database_name}"
    # DB_USER         = "${var.rds_database_username}"
    # DB_PORT         = "${var.rds_database_port}"
    # SQS_QUEUE_URL   = "${module.sqs.queue_url}"
  }

  depends_on = [
    module.github_oidc,
    module.ecr
  ]
}

module "aws_auth_config" {
  source = "../modules/aws_auth_config"

  aws_region = var.aws_region
  cluster_name = module.eks.cluster_name
  github_oidc_role_arn = var.github_oidc_role_arn

  map_roles = [
    {
      rolearn  = "${module.eks.node_group_role_arn}"
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = [
        "system:bootstrappers",
        "system:nodes"
      ]
    },
    {
      rolearn  = "${var.github_oidc_role_arn}"
      username = "github"
      groups   = ["system:masters"]
    }
  ]

  eks_user_access_map = local.map_users

  depends_on = [module.eks]
  eks_dependency = module.eks
}

module "argocd" {
  source         = "../modules/helm/argocd"

  project_tag        = var.project_tag
  environment        = var.environment

  release_name          = "argocd-${var.environment}"
  service_account_name  = "argocd-${var.environment}-service-account"
  namespace             = var.argocd_namespace
  chart_version         = var.argocd_chart_version

  oidc_provider_arn     = module.eks.oidc_provider_arn
  oidc_provider_url     = module.eks.cluster_oidc_issuer_url

  vpc_id = module.vpc_network.vpc_id
  ingress_controller_class  = "alb"
  alb_group_name           = "${var.project_tag}-${var.environment}-alb-shared-group"
  argocd_allowed_cidr_blocks   = var.argocd_allowed_cidr_blocks
  domain_name               = "${var.argocd_base_domain_name}-${var.environment}.${var.subdomain_name}.${var.domain_name}"
  acm_cert_arn              = module.acm.this_certificate_arn
  node_group_security_group = module.eks.node_group_security_group_id
  backend_security_group_id = module.backend.security_group_id
  frontend_security_group_id = module.frontend.security_group_id

  secret_arn = module.secrets_app_envs.app_secrets_arns["${var.argocd_aws_secret_key}"]

  lbc_webhook_ready = module.aws_load_balancer_controller.webhook_ready
  depends_on = [
    module.eks,
    module.acm,
    module.backend,
    module.frontend,
    module.secrets_app_envs
  ]
}
 
module "external_secrets_operator" {
  source        = "../modules/helm/external-secrets-operator"
  
  chart_version = "0.9.17"

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.cluster_oidc_issuer_url

  service_account_name = "eso-${var.environment}-service-account"
  release_name       = "external-secrets-${var.environment}"
  namespace          = "external-secrets"
  argocd_namespace   = var.argocd_namespace
  argocd_service_account_name  = "argocd-${var.environment}-service-account"
  project_tag        = var.project_tag
  environment        = var.environment
  aws_region         = var.aws_region
  argocd_service_account_role_arn = module.argocd.service_account_role_arn
  argocd_secret_name = module.secrets_app_envs.app_secrets_names["${var.argocd_aws_secret_key}"]

  set_values = [
    # {
    #   name  = "webhook.port"
    #   value = "10250"
    # },
    # {
    #   name  = "serviceAccount.create"
    #   value = "true"
    # }
  ]
  
  lbc_webhook_ready = module.aws_load_balancer_controller.webhook_ready
  depends_on = [
    module.eks,
    module.aws_auth_config,
    module.argocd,
    module.secrets_app_envs
  ]
}

module "aws_load_balancer_controller" {
  source        = "../modules/helm/aws-load-balancer-controller"
  
  project_tag        = var.project_tag
  environment        = var.environment

  service_account_name = "aws-load-balancer-controller-${var.environment}-service-account"
  release_name         = "aws-load-balancer-controller-${var.environment}"
  namespace            = "kube-system"
  cluster_name       = module.eks.cluster_name
  vpc_id             = module.vpc_network.vpc_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.cluster_oidc_issuer_url

  depends_on = [module.eks]
}
