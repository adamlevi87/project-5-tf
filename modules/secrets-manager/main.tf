# modules/secrets-manager/main.tf

# Generate random passwords for secrets that need them
resource "random_password" "secrets" {
  for_each = {
    for name, config in var.secrets : name => config
    if config.generate_password == true
  }

  length  = each.value.password_length
  special = each.value.password_special
}

# Create secrets in AWS Secrets Manager
resource "aws_secretsmanager_secret" "secrets" {
  for_each = var.secrets

  name        = "${var.project_tag}-${var.environment}-${each.key}"
  description = each.value.description

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
  for_each = var.secrets

  secret_id = aws_secretsmanager_secret.secrets[each.key].id
  
  secret_string = each.value.generate_password ? random_password.secrets[each.key].result : each.value.secret_value
}