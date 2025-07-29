# modules/aws_load_balancer_controller/main.tf

locals {
  aws_load_balancer_controller = "aws-load-balancer-controller"
}

# Install AWS Load Balancer Controller via Helm
resource "helm_release" "aws_load_balancer_controller" {
  name       = "${local.aws_load_balancer_controller}"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  create_namespace = false
  version    = "1.13.3"  # Latest stable version

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"  # We create it manually above
  }

  set {
    name  = "serviceAccount.name"
    value = "${local.aws_load_balancer_controller}"
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }
}

# IAM role for AWS Load Balancer Controller
resource "aws_iam_role" "load_balancer_controller" {
  name = "${var.project_tag}-${var.environment}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-aws-load-balancer-controller"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "aws-load-balancer-controller"
  }
}

# IAM policy for AWS Load Balancer Controller
resource "aws_iam_policy" "load_balancer_controller" {
  name        = "${var.project_tag}-${var.environment}-aws-load-balancer-controller"
  description = "IAM policy for AWS Load Balancer Controller"

  policy = jsonencode(
    {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "iam:CreateServiceLinkedRole"
              ],
              "Resource": "*",
              "Condition": {
                  "StringEquals": {
                      "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": [
                  "ec2:DescribeAccountAttributes",
                  "ec2:DescribeAddresses",
                  "ec2:DescribeAvailabilityZones",
                  "ec2:DescribeInternetGateways",
                  "ec2:DescribeVpcs",
                  "ec2:DescribeVpcPeeringConnections",
                  "ec2:DescribeSubnets",
                  "ec2:DescribeSecurityGroups",
                  "ec2:DescribeInstances",
                  "ec2:DescribeNetworkInterfaces",
                  "ec2:DescribeTags",
                  "ec2:GetCoipPoolUsage",
                  "ec2:DescribeCoipPools",
                  "ec2:GetSecurityGroupsForVpc",
                  "ec2:DescribeIpamPools",
                  "ec2:DescribeRouteTables",
                  "elasticloadbalancing:DescribeLoadBalancers",
                  "elasticloadbalancing:DescribeLoadBalancerAttributes",
                  "elasticloadbalancing:DescribeListeners",
                  "elasticloadbalancing:DescribeListenerCertificates",
                  "elasticloadbalancing:DescribeSSLPolicies",
                  "elasticloadbalancing:DescribeRules",
                  "elasticloadbalancing:DescribeTargetGroups",
                  "elasticloadbalancing:DescribeTargetGroupAttributes",
                  "elasticloadbalancing:DescribeTargetHealth",
                  "elasticloadbalancing:DescribeTags",
                  "elasticloadbalancing:DescribeTrustStores",
                  "elasticloadbalancing:DescribeListenerAttributes",
                  "elasticloadbalancing:DescribeCapacityReservation"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "cognito-idp:DescribeUserPoolClient",
                  "acm:ListCertificates",
                  "acm:DescribeCertificate",
                  "iam:ListServerCertificates",
                  "iam:GetServerCertificate",
                  "waf-regional:GetWebACL",
                  "waf-regional:GetWebACLForResource",
                  "waf-regional:AssociateWebACL",
                  "waf-regional:DisassociateWebACL",
                  "wafv2:GetWebACL",
                  "wafv2:GetWebACLForResource",
                  "wafv2:AssociateWebACL",
                  "wafv2:DisassociateWebACL",
                  "shield:GetSubscriptionState",
                  "shield:DescribeProtection",
                  "shield:CreateProtection",
                  "shield:DeleteProtection"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "ec2:AuthorizeSecurityGroupIngress",
                  "ec2:RevokeSecurityGroupIngress"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "ec2:CreateSecurityGroup"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "ec2:CreateTags"
              ],
              "Resource": "arn:aws:ec2:*:*:security-group/*",
              "Condition": {
                  "StringEquals": {
                      "ec2:CreateAction": "CreateSecurityGroup"
                  },
                  "Null": {
                      "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": [
                  "ec2:CreateTags",
                  "ec2:DeleteTags"
              ],
              "Resource": "arn:aws:ec2:*:*:security-group/*",
              "Condition": {
                  "Null": {
                      "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                      "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": [
                  "ec2:AuthorizeSecurityGroupIngress",
                  "ec2:RevokeSecurityGroupIngress",
                  "ec2:DeleteSecurityGroup"
              ],
              "Resource": "*",
              "Condition": {
                  "Null": {
                      "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": [
                  "elasticloadbalancing:CreateLoadBalancer",
                  "elasticloadbalancing:CreateTargetGroup"
              ],
              "Resource": "*",
              "Condition": {
                  "Null": {
                      "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": [
                  "elasticloadbalancing:CreateListener",
                  "elasticloadbalancing:DeleteListener",
                  "elasticloadbalancing:CreateRule",
                  "elasticloadbalancing:DeleteRule"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "elasticloadbalancing:AddTags",
                  "elasticloadbalancing:RemoveTags"
              ],
              "Resource": [
                  "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                  "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                  "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
              ],
              "Condition": {
                  "Null": {
                      "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                      "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": [
                  "elasticloadbalancing:AddTags",
                  "elasticloadbalancing:RemoveTags"
              ],
              "Resource": [
                  "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
                  "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
                  "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
                  "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
              ]
          },
          {
              "Effect": "Allow",
              "Action": [
                  "elasticloadbalancing:ModifyLoadBalancerAttributes",
                  "elasticloadbalancing:SetIpAddressType",
                  "elasticloadbalancing:SetSecurityGroups",
                  "elasticloadbalancing:SetSubnets",
                  "elasticloadbalancing:DeleteLoadBalancer",
                  "elasticloadbalancing:ModifyTargetGroup",
                  "elasticloadbalancing:ModifyTargetGroupAttributes",
                  "elasticloadbalancing:DeleteTargetGroup",
                  "elasticloadbalancing:ModifyListenerAttributes",
                  "elasticloadbalancing:ModifyCapacityReservation",
                  "elasticloadbalancing:ModifyIpPools"
              ],
              "Resource": "*",
              "Condition": {
                  "Null": {
                      "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": [
                  "elasticloadbalancing:AddTags"
              ],
              "Resource": [
                  "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                  "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                  "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
              ],
              "Condition": {
                  "StringEquals": {
                      "elasticloadbalancing:CreateAction": [
                          "CreateTargetGroup",
                          "CreateLoadBalancer"
                      ]
                  },
                  "Null": {
                      "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": [
                  "elasticloadbalancing:RegisterTargets",
                  "elasticloadbalancing:DeregisterTargets"
              ],
              "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "elasticloadbalancing:SetWebAcl",
                  "elasticloadbalancing:ModifyListener",
                  "elasticloadbalancing:AddListenerCertificates",
                  "elasticloadbalancing:RemoveListenerCertificates",
                  "elasticloadbalancing:ModifyRule",
                  "elasticloadbalancing:SetRulePriorities"
              ],
              "Resource": "*"
          }
      ]
    }
  )
  
  tags = {
    Name        = "${var.project_tag}-${var.environment}-aws-load-balancer-controller-policy"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "aws-load-balancer-controller"
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  policy_arn = aws_iam_policy.load_balancer_controller.arn
  role       = aws_iam_role.load_balancer_controller.name
}

# Kubernetes service account for AWS Load Balancer Controller
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "${local.aws_load_balancer_controller}"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.load_balancer_controller.arn
    }
  }
}
