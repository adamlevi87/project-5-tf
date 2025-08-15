# modules/gitops-workflow/main.tf

terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.6.0"
    }
  }
}

# Data source to get the repository
data "github_repository" "gitops_repo" {
  full_name = "${var.gitops_repo_owner}/${var.github_gitops_repo}"
}

data "github_repository_file" "current_files" {
  for_each = toset(concat(
    # Always check infra files
    [local.frontend_infra_values_path, local.backend_infra_values_path],
    # Conditionally check bootstrap files
    var.bootstrap_mode ? [
      local.project_yaml_path,
      local.frontend_app_path,
      local.backend_app_path,
      local.frontend_app_values_path,
      local.backend_app_values_path
    ] : []
  ))
  
  repository = data.github_repository.gitops_repo.name
  file       = each.value
  branch     = var.target_branch
}

# CHANGED: Added local.has_changes condition to branch creation
resource "github_branch" "gitops_branch" {
  count = local.has_changes && (var.bootstrap_mode || var.update_apps) ? 1 : 0
  
  repository = data.github_repository.gitops_repo.name
  branch     = local.branch_name
  source_branch = var.target_branch

  depends_on = [data.github_repository_file.current_files]
}

# Bootstrap files (only in bootstrap mode)
resource "github_repository_file" "bootstrap_files" {
  for_each = var.bootstrap_mode && local.has_changes ? {
    "project"              = { path = local.project_yaml_path, content = local.rendered_project }
    "frontend_application" = { path = local.frontend_app_path, content = local.rendered_frontend_app }
    "backend_application"  = { path = local.backend_app_path, content = local.rendered_backend_app }
    "frontend_app_values"  = { path = local.frontend_app_values_path, content = local.rendered_frontend_app_values }
    "backend_app_values"   = { path = local.backend_app_values_path, content = local.rendered_backend_app_values }
  } : {}
  
  repository = data.github_repository.gitops_repo.name
  file       = each.value.path
  content    = each.value.content
  branch     = github_branch.gitops_branch[0].branch
  
  commit_message = "Bootstrap: Create ${each.key}"
  commit_author  = "Terraform GitOps"
  commit_email   = "terraform@gitops.local"
  
  overwrite_on_create = true

  depends_on = [data.github_repository_file.current_files]
}

# Infrastructure files (bootstrap OR update mode)
resource "github_repository_file" "infra_files" {
  for_each = local.has_changes && (var.bootstrap_mode || var.update_apps) ? {
    "frontend_infra" = { path = local.frontend_infra_values_path, content = local.rendered_frontend_infra }
    "backend_infra"  = { path = local.backend_infra_values_path, content = local.rendered_backend_infra }
  } : {}
  
  repository = data.github_repository.gitops_repo.name
  file       = each.value.path
  content    = each.value.content
  branch     = github_branch.gitops_branch[0].branch
  
  commit_message = var.bootstrap_mode ? "Bootstrap: Create ${each.key} values" : "Update: ${each.key} values for ${var.environment}"
  commit_author  = "Terraform GitOps"
  commit_email   = "terraform@gitops.local"
  
  overwrite_on_create = true
  depends_on = [github_repository_file.bootstrap_files]
}

# Always create PR
resource "github_repository_pull_request" "gitops_pr" {
  count = local.has_changes && (var.bootstrap_mode || var.update_apps) ? 1 : 0
  
  base_repository   = data.github_repository.gitops_repo.name
  title             = var.bootstrap_mode ? "Bootstrap: ${var.project_tag} ${var.environment}" : "Update: ${var.environment} infrastructure"
  body              = var.bootstrap_mode ? "Bootstrap GitOps configuration for ${var.project_tag}" : "Update infrastructure values for ${var.environment}"
  head_ref          = github_branch.gitops_branch[0].branch
  base_ref          = var.target_branch
  
  depends_on = [
      data.github_repository_file.current_files,
      github_repository_file.infra_files
    ]
}

# Change detection using null_resource with local-exec
resource "null_resource" "change_detection" {
  triggers = {
    bootstrap_mode = var.bootstrap_mode
    update_apps    = var.update_apps
    # Force re-evaluation when mode variables change
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Checking for file changes..."
      
      # Create temp directory for comparison
      mkdir -p /tmp/terraform-gitops-compare
      
      # Initialize has_changes flag
      echo "false" > /tmp/terraform-gitops-compare/has_changes
      
      # Function to check if file changed
      check_file_change() {
        local file_path="$1"
        local rendered_content="$2"
        
        # Get current file content from GitHub (base64 encoded)
        current_content=$(gh api repos/${var.gitops_repo_owner}/${var.github_gitops_repo}/contents/"$file_path" \
          --jq '.content' 2>/dev/null || echo "")
        
        # Encode our rendered content to base64
        our_content=$(echo -n "$rendered_content" | base64 -w 0)
        
        # Compare
        if [ "$current_content" != "$our_content" ]; then
          echo "true" > /tmp/terraform-gitops-compare/has_changes
          echo "File changed: $file_path"
        fi
      }
      
      # Check infra files (always)
      check_file_change "manifests/frontend/infra-values.yaml" "${local.rendered_frontend_infra}"
      check_file_change "manifests/backend/infra-values.yaml" "${local.rendered_backend_infra}"
      
      # Check bootstrap files (if bootstrap mode)
      if [ "${var.bootstrap_mode}" = "true" ]; then
        check_file_change "projects/${var.project_tag}.yaml" "${local.rendered_project}"
        check_file_change "apps/frontend/application.yaml" "${local.rendered_frontend_app}"
        check_file_change "apps/backend/application.yaml" "${local.rendered_backend_app}"
        check_file_change "manifests/frontend/app-values.yaml" "${local.rendered_frontend_app_values}"
        check_file_change "manifests/backend/app-values.yaml" "${local.rendered_backend_app_values}"
      fi
      
      echo "Change detection complete."
    EOT
  }
}

# Read the result of change detection
data "local_file" "has_changes" {
  filename = "/tmp/terraform-gitops-compare/has_changes"
  depends_on = [null_resource.change_detection]
}
