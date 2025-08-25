# modules/gitops-workflow/main.tf

terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.6.0"
    }
  }
}

# # Data source to get the repository
# data "github_repository" "gitops_repo" {
#   full_name = "${var.gitops_repo_owner}/${var.github_gitops_repo}"
# }

# data "github_repository_file" "current_files" {
#   for_each = toset(concat(
#     # Always check infra files
#     [local.frontend_infra_values_path, local.backend_infra_values_path],
#     # Conditionally check bootstrap files
#     var.bootstrap_mode ? [
#       local.project_yaml_path,
#       local.frontend_app_path,
#       local.backend_app_path,
#       local.frontend_app_values_path,
#       local.backend_app_values_path
#     ] : []
#   ))
  
#   repository = data.github_repository.gitops_repo.name
#   file       = each.value
#   branch     = var.target_branch
# }

resource "github_branch" "gitops_branch" { 
  repository = var.gitops_repo_name
  branch     = local.branch_name
  source_branch = var.target_branch
}

# Bootstrap files (only in bootstrap mode)
resource "github_repository_file" "bootstrap_files" {
  for_each = var.bootstrap_mode ? {
    "project"              = { path = local.project_yaml_path, content = local.rendered_project }
    "frontend_application" = { path = local.frontend_app_path, content = local.rendered_frontend_app }
    "backend_application"  = { path = local.backend_app_path, content = local.rendered_backend_app }
    "frontend_app_values"  = { path = local.frontend_app_values_path, content = local.rendered_frontend_app_values }
    "backend_app_values"   = { path = local.backend_app_values_path, content = local.rendered_backend_app_values }
  } : {}
  
  repository = var.gitops_repo_name
  file       = each.value.path
  content    = each.value.content
  branch     = github_branch.gitops_branch.branch
  
  commit_message = "Bootstrap: Create ${each.key}"
  commit_author  = "Terraform GitOps"
  commit_email   = "terraform@gitops.local"
  
  overwrite_on_create = true
}

# Infrastructure files (bootstrap OR update mode)
resource "github_repository_file" "infra_files" {
  for_each = var.bootstrap_mode || var.update_apps ? {
    "frontend_infra" = { path = local.frontend_infra_values_path, content = local.rendered_frontend_infra }
    "backend_infra"  = { path = local.backend_infra_values_path, content = local.rendered_backend_infra }
  } : {}
  
  repository = var.gitops_repo_name
  file       = each.value.path
  content    = each.value.content
  branch     = github_branch.gitops_branch[0].branch
  
  commit_message = var.bootstrap_mode ? "Bootstrap: Create ${each.key} values" : "Update: ${each.key} values for ${var.environment}"
  commit_author  = "Terraform GitOps"
  commit_email   = "terraform@gitops.local"
  
  overwrite_on_create = true
  depends_on = [
    github_repository_file.bootstrap_files
  ]
}

# Always create PR
resource "github_repository_pull_request" "gitops_pr" {  
  base_repository   = var.gitops_repo_name
  title             = var.bootstrap_mode ? "Bootstrap: ${var.project_tag} ${var.environment}" : "Update: ${var.environment} infrastructure"
  body              = var.bootstrap_mode ? "Bootstrap GitOps configuration for ${var.project_tag}" : "Update infrastructure values for ${var.environment}"
  head_ref          = github_branch.gitops_branch[0].branch
  base_ref          = var.target_branch
  
  depends_on = [
      github_repository_file.infra_files
    ]
}
