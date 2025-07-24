resource "github_actions_secret" "secrets" {
  for_each        = var.github_secrets
  repository      = var.repository_name
  secret_name     = each.key
  plaintext_value = each.value

  lifecycle {
  ignore_changes = [plaintext_value]
  }
}

resource "github_actions_variable" "variables" {
  for_each        = var.github_variables
  repository      = var.repository_name
  variable_name   = each.key
  value           = each.value

  lifecycle {
  ignore_changes = [value]
  }
}