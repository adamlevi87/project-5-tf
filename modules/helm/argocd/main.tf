# modules/argocd/main.tf

# terraform {
#   required_providers {
#     kubernetes = {
#       source  = "hashicorp/kubernetes"
#       version = "~> 2.38"
#     }
#     helm = {
#       source  = "hashicorp/helm"
#       version = "~> 3.0.2"
#     }
#   }
# }

locals {
  joined_security_group_ids = "${aws_security_group.argocd.id},${var.frontend_security_group_id},${var.backend_security_group_id}"
  
  argocd_additionalObjects = [
    # 1) setting up the Project
    {
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "AppProject"
      metadata = {
        name      = "${var.project_tag}"
        namespace = "${var.namespace}"
        annotations = {
          "helm.sh/hook"                = "post-install,post-upgrade"
          "helm.sh/hook-weight"         = "1"
          "helm.sh/hook-delete-policy"  = "before-hook-creation"
        }
      }
      spec = {
        description = "${var.project_tag} apps and infra"
        sourceRepos = [
          "https://github.com/${var.github_org}/${var.github_gitops_repo}.git",
          "https://github.com/${var.github_org}/${var.github_application_repo}.git"
        ]
        destinations = [
          {
            namespace = "*"
            server    = "https://kubernetes.default.svc"
          }
        ]
        namespaceResourceWhitelist = [
          {
            group = "external-secrets.io"
            kind  = "SecretStore"
          },
          {
            group = "external-secrets.io"
            kind  = "ExternalSecret"
          },
          {
            group = ""
            kind  = "Secret"
          },
          {
            group = ""
            kind  = "ServiceAccount"
          },
          {
            group = "networking.k8s.io"
            kind  = "Ingress"
          },
          {
            group = ""
            kind  = "Service"
          },
          {
            group = "apps"
            kind  = "Deployment"
          },
          {
            group = "argoproj.io"
            kind  = "Application"
          },
          {
            group = "autoscaling"
            kind  = "HorizontalPodAutoscaler"
          }
        ]
        clusterResourceWhitelist = []
        orphanedResources = {
          warn = true
        }
      } 
    },
    # 2) setting up App-of-Apps
    {
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = "${var.project_tag}-app-of-apps-${var.environment}"
        namespace = "${var.namespace}"
        annotations = {
          "helm.sh/hook"                 = "post-install,post-upgrade"
          "helm.sh/hook-weight"          = "5"
          "helm.sh/hook-delete-policy"   = "before-hook-creation"
          "argocd.argoproj.io/sync-wave" = "-10"
        }
      }
      spec = {
        project = "${var.project_tag}"
        source = {
          repoURL        = "https://github.com/${var.github_org}/${var.github_gitops_repo}.git"
          path           = "environments/${var.environment}/${var.app_of_apps_path}"
          targetRevision = "${var.app_of_apps_target_revision}"
          directory = {
            recurse = true
          }
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "default"
        }
        revisionHistoryLimit = 3
        syncPolicy = {
          retry = {
            limit = 5
            backoff = {
              duration    = "5s"
              factor      = 2
              maxDuration = "3m"
            }
          }
          syncOptions = [
            "CreateNamespace=true",
            "PruneLast=true",
            "PrunePropagationPolicy=background",
            "ApplyOutOfSyncOnly=true"
          ]
        }
      }
    }
  ]
}

resource "random_password" "argocd_server_secretkey" {
  length  = 48
  special = false
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "this" {
  name       = var.release_name
  
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version
  
  namespace  = var.namespace
  create_namespace = false

  # set = [
  #   {
  #     name  = "serviceAccount.create"
  #     value = "false"  # We create it manually above
  #   },
  #   {
  #     name  = "serviceAccount.name"
  #     value = "${var.service_account_name}"
  #   }
  # ]

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      service_account_name        = var.service_account_name
      #environment                = var.environment
      domain_name                 = var.domain_name
      ingress_controller_class    = var.ingress_controller_class
      alb_group_name              = var.alb_group_name
      release_name                = var.release_name
      allowed_cidrs               = jsonencode(var.argocd_allowed_cidr_blocks)
      security_group_id           = local.joined_security_group_ids
      acm_cert_arn                = var.acm_cert_arn
      server_secretkey            = random_password.argocd_server_secretkey.result
      #github_oauth_client_id      = var.github_oauth_client_id
      github_org                  = var.github_org
      github_admin_team           = var.github_admin_team
      github_readonly_team        = var.github_readonly_team
      dollar                      = "$"
      argocd_github_sso_secret_name = var.argocd_github_sso_secret_name
    }),
    yamlencode({
      extraObjects = local.argocd_additionalObjects
    })
  ]
  
  depends_on = [
      kubernetes_namespace.this,
      kubernetes_service_account.this,
      aws_security_group.argocd,
      var.lbc_webhook_ready
  ]
}

# resource "local_file" "rendered_argo_values" {
#   content  = templatefile("${path.module}/values.yaml", {
#     service_account_name = var.service_account_name
#     #environment         = var.environment
#     domain_name         = var.domain_name
#     ingress_controller_class  = var.ingress_controller_class
#     alb_group_name           = var.alb_group_name
#     #allowed_cidrs            = join(",", var.argocd_allowed_cidr_blocks)
#     security_group_id         = local.joined_security_group_ids
#     acm_cert_arn              = var.acm_cert_arn
#   })

#   filename = "${path.module}/rendered-values-debug.yaml"

#   depends_on = [
#       kubernetes_service_account.this,
#       aws_security_group.argocd
#   ]
# }


# Kubernetes service account
resource "kubernetes_service_account" "this" {
  metadata {
    name      = "${var.service_account_name}"
    namespace = "${var.namespace}"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
    }
  }
}

resource "aws_iam_role" "this" {
  name = "${var.service_account_name}-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity",
        Effect = "Allow",
        Principal = {
          Federated = var.oidc_provider_arn
        },
        Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}",
          "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
      }
    ]
  })
}

resource "aws_iam_role_policy" "this" {
  name = "${var.service_account_name}-policy"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "${var.secret_arn}"
      }
    ]
  })
}

# Security Group for ArgoCD
resource "aws_security_group" "argocd" {
  name        = "${var.project_tag}-${var.environment}-argocd-sg"
  description = "Security group for argocd"
  vpc_id      = var.vpc_id

  # Allow ArgoCD access from the outside
  dynamic "ingress" {
    for_each = [80, 443]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.argocd_allowed_cidr_blocks
      description = "ArgoCD access on port ${ingress.value}"
    }
  }

  # Outbound rules (usually not needed but good practice)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name        = "${var.project_tag}-${var.environment}-argocd-sg"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "argocd-security"
  }
}

resource "aws_security_group_rule" "allow_alb_to_argocd_pods" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  #security_group_id        = tolist(data.aws_instance.first_node.security_groups)[0]  # or manually "sg-0a9d986ac63a06d9f"
  security_group_id        = var.node_group_security_group
  source_security_group_id = aws_security_group.argocd.id
  description              = "Allow ALB to access ArgoCD pods on port 8080"
}


# # temporary initial app

# resource "kubernetes_manifest" "argocd_smoke_app" {
#   manifest = {
#     apiVersion = "argoproj.io/v1alpha1"
#     kind       = "Application"
#     metadata = {
#       name      = "repo-smoke"
#       namespace = "argocd"
#       annotations = {
#         "argocd.argoproj.io/sync-wave" = "0"
#       }
#     }
#     spec = {
#       project = "default"
#       source = {
#         repoURL        = "https://github.com/adamlevi87/project-5-gitops"     # must match the repo used in your repository-type Secret
#         targetRevision = "main"
#         path           = "smoke"    # a folder in that repo with a simple manifest (e.g., a ConfigMap)
#       }
#       destination = {
#         server    = "https://kubernetes.default.svc"
#         namespace = "argocd-smoke"
#       }
#       syncPolicy = {
#         automated = {
#           prune    = false
#           selfHeal = false
#         }
#         syncOptions = [
#           "CreateNamespace=true",
#           "PrunePropagationPolicy=foreground"
#         ]
#       }
#     }
#   }

#   depends_on = [helm_release.this]
# }