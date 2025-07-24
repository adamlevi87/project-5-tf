# modules/rds/main.tf

# DB Subnet Group - spans all private subnets across AZs
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_tag}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project_tag}-${var.environment}-db-subnet-group"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "database-networking"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.project_tag}-${var.environment}-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = var.vpc_id

  # Allow PostgreSQL access from backend applications
  ingress {
    from_port   = var.rds_database_port
    to_port     = var.rds_database_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "PostgreSQL access from backend"
  }

  # Outbound rules (usually not needed for RDS but good practice)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name        = "${var.project_tag}-${var.environment}-rds-sg"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "database-security"
  }
}

# Get password from Secrets Manager
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = var.db_password_secret_arn
}

# RDS Instance
resource "aws_db_instance" "main" {
  # Database configuration
  identifier     = "${var.project_tag}-${var.environment}-db"
  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.instance_class
  
  # Database details
  db_name  = var.database_name
  username = var.database_username
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
  port     = var.rds_database_port
  
  # Storage configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = true
  
  # Multi-AZ and networking
  multi_az               = true  # Always enabled for high availability
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  
  # Backup configuration
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  
  # Deletion protection
  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  
  # Performance and monitoring
  performance_insights_enabled = var.enable_performance_insights
  monitoring_interval         = var.monitoring_interval
  
  tags = {
    Name        = "${var.project_tag}-${var.environment}-db"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "application-database"
  }
}