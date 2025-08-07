# modules/secrets-manager/main.tf

# Create secrets in AWS Secrets Manager
resource "aws_secretsmanager_secret" "secrets" {
  for_each = var.secrets_config_with_passwords

  name        = "${var.project_tag}-${var.environment}-${each.key}"
  description = each.value.description
  recovery_window_in_days = 0  # Force immediate deletion for dev environments

  tags = {
    Name        = "${var.project_tag}-${var.environment}-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "application-secrets"
    SecretType  = each.key
  }
}

# Store secret values
resource "aws_secretsmanager_secret_version" "secrets" {
  for_each = var.secrets_config_with_passwords

  secret_id = aws_secretsmanager_secret.secrets[each.key].id
  
  secret_string = each.value.secret_value
}

resource "aws_secretsmanager_secret" "app_secrets" {
  for_each = var.app_secrets_config

  name        = "${var.project_tag}-${var.environment}-${each.key}"
  description = each.value.description
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.project_tag}-${var.environment}-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "application-secrets"
    SecretType  = each.key
  }
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  for_each = var.app_secrets_config

  secret_id     = aws_secretsmanager_secret.app_secrets[each.key].id
  secret_string = each.value.secret_value
}
