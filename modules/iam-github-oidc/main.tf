# modules/iam-github-oidc/main.tf

resource "aws_iam_role" "github_actions" {
  # the name will be project-5-dev-APP_REPO-github-actions-role
  # as APP_REPO = project-5-app , final name will be:
  # project-5-dev-project-5-app-github-actions-role
  # might look like a duplication but its fine
  name = "1-${var.project_tag}-${var.environment}-${var.github_repo}-github-actions-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity",
        Effect = "Allow",
        Principal = {
          # Federated = aws_iam_openid_connect_provider.github.arn
          Federated = var.aws_iam_openid_connect_provider_github_arn
        },
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_admin_policy" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}