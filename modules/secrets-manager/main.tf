# modules/secrets-manager/main.tf

# Generate passwords in main (optional - can stay in module)
resource "random_password" "generated_passwords" {
  for_each = {
    for name, config in var.secrets_config : name => config
    if config.generate_password == true
  }
  
  length  = each.value.password_length
  special = each.value.password_special

  override_special = each.value.password_override_special != "" ? each.value.password_override_special : null
  
  lifecycle {
    ignore_changes = [result]
  }
}

locals {
  # Merge generated passwords into the configuration
    secrets_with_passwords = {
      for name, config in var.secrets_config : name => merge(config, {
        secret_value = config.generate_password ? random_password.generated_passwords[name].result : config.secret_value
      })
    }
}

# Create secrets in AWS Secrets Manager
resource "aws_secretsmanager_secret" "secrets" {
  for_each = local.secrets_with_passwords

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
  for_each = local.secrets_with_passwords

  secret_id = aws_secretsmanager_secret.secrets[each.key].id
  
  secret_string = each.value.generate_password ? random_password.generated_passwords[each.key].result : each.value.secret_value
}