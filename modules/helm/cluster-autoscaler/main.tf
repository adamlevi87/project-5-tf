# modules/cluster-autoscaler/main.tf

resource "helm_release" "this" {
  name       = "${release_name}"
  
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  
  namespace  = "${var.namespace}"
  create_namespace = false

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = var.service_account_name
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "extraArgs.balance-similar-node-groups"
    value = "true"
  }

  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = "false"
  }

  set {
    name  = "extraArgs.skip-nodes-with-local-storage"
    value = "false"
  }

  depends_on = [
    aws_iam_role_policy_attachment.this,
    kubernetes_service_account.this
  ]
}

resource "aws_iam_role" "this" {
  name = "${var.project_tag}-${var.environment}-cluster-autoscaler"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = var.oidc_provider_arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
        }
      }
    }]
  })

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "cluster-autoscaler"
  }
}

resource "aws_iam_policy" "this" {
  name = "${var.project_tag}-${var.environment}-cluster-autoscaler-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
        {
        Effect = "Allow",
        Action = [
            "autoscaling:DescribeAutoScalingGroups",
            "autoscaling:DescribeAutoScalingInstances",
            "autoscaling:DescribeLaunchConfigurations",
            "autoscaling:DescribeTags",
            "autoscaling:SetDesiredCapacity",
            "autoscaling:TerminateInstanceInAutoScalingGroup",
            "ec2:DescribeLaunchTemplateVersions"
        ],
        Resource = "*"
        }
    ]
  })
 
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "cluster-autoscaler"
  }
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

resource "kubernetes_service_account" "this" {
  metadata {
    name      = "${var.service_account_name}"
    namespace = "${var.namespace}"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
    }
  }
}

