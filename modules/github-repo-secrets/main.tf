# modules/iam-github-oidc/main.tf

locals {
  env_suffix = upper(var.environment)

  secrets_with_env_suffix = {
    for k, v in var.github_secrets :
    "${k}_TF_${local.env_suffix}" => v
  }

  variables_with_env_suffix = {
    for k, v in var.github_variables :
    "${k}_TF_${local.env_suffix}" => v
  }
}

resource "github_actions_secret" "secrets" {
  for_each        = local.secrets_with_env_suffix
  repository      = var.repository_name
  secret_name     = each.key
  plaintext_value = each.value

  lifecycle {
  ignore_changes = [plaintext_value]
  }
}

resource "github_actions_variable" "variables" {
  for_each        = local.variables_with_env_suffix
  repository      = var.repository_name
  variable_name   = each.key
  value           = each.value

  lifecycle {
  ignore_changes = [value]
  }
}