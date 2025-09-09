# modules/eks/main.tf

locals {
  ecr_arn_list = values(var.ecr_repository_arns)
  
  # Create nodeadm config per node group
  nodeadm_configs = {
    for ng_name, ng_config in var.node_groups : ng_name => templatefile("${path.module}/nodeadm-config.yaml.tpl", {
      cluster_name        = aws_eks_cluster.main.name
      cluster_endpoint    = aws_eks_cluster.main.endpoint
      cluster_ca          = aws_eks_cluster.main.certificate_authority[0].data
      cluster_cidr        = aws_eks_cluster.main.kubernetes_network_config[0].service_ipv4_cidr
      nodegroup_name      = ng_name
      node_labels         = ng_config.labels
    })
  }
  
  # Create user data per node group
  user_data_configs = {
    for ng_name, ng_config in var.node_groups : ng_name => <<-EOF
      MIME-Version: 1.0
      Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

      --==MYBOUNDARY==
      Content-Type: application/node.eks.aws

      ${local.nodeadm_configs[ng_name]}
      --==MYBOUNDARY==--
    EOF
  }

  # Create all node group security group IDs for cross-communication
  all_node_sg_ids = [for ng_name, ng_config in var.node_groups : aws_security_group.nodes[ng_name].id]

  # Create a flattened list of node group pairs for cross-communication
  # Create all possible pairs of node groups (excluding self-pairs)
  node_group_pairs = flatten([
    for ng1_name, ng1_config in var.node_groups : [
      for ng2_name, ng2_config in var.node_groups : {
        source = ng1_name
        target = ng2_name
      }
      if ng1_name != ng2_name
    ]
  ])
}

# EKS Cluster IAM Role
resource "aws_iam_role" "cluster_role" {
  name = "${var.project_tag}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-eks-cluster-role"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "eks-cluster"
  }
}

# Attach required policies to cluster role
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_role.name
}

# EKS Node Group IAM Role
resource "aws_iam_role" "node_group_role" {
  name = "${var.project_tag}-${var.environment}-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-eks-node-group-role"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "eks-nodes"
  }
}

resource "aws_iam_role_policy" "ecr_pull" {
  name = "ecr-pull"
  role = aws_iam_role.node_group_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        Resource = local.ecr_arn_list
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_group_ssm" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "node_group_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_group_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_group_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group_role.name
}

# CloudWatch Log Group for EKS cluster
resource "aws_cloudwatch_log_group" "cluster_logs" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days

  tags = {
    Name        = "${var.project_tag}-${var.environment}-eks-logs"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "eks-logging"
  }
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster_role.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.eks_api_allowed_cidr_blocks
  }

  enabled_cluster_log_types = var.cluster_enabled_log_types != null ? var.cluster_enabled_log_types : []

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_cloudwatch_log_group.cluster_logs
  ]

  tags = {
    Name        = var.cluster_name
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "kubernetes-cluster"
  }
}

# Get OIDC issuer certificate
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# IAM OIDC provider for the cluster
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name        = "${var.project_tag}-${var.environment}-eks-oidc"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "eks-oidc-provider"
  }
}

# Node group security groups - one per node group
resource "aws_security_group" "nodes" {
  for_each = var.node_groups

  name        = "${var.project_tag}-${var.environment}-eks-${each.key}-sg"
  description = "EKS worker node SG for ${each.key} node group"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_tag}-${var.environment}-eks-${each.key}-sg"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "eks-worker-nodes"
    NodeGroup   = each.key
  }
}

# AMI data source (kept for fallback)
data "aws_ami" "eks_default" {
  most_recent = true
  owners      = ["602401143452"]  # Amazon EKS AMI owner (official)
  
  filter {
    name   = "name"
    values = ["amazon-eks-node-*-x86_64-*"]
  }
}

# Launch templates - one per node group
resource "aws_launch_template" "nodes" {
  for_each = var.node_groups

  name_prefix   = "${var.project_tag}-${var.environment}-eks-${each.key}-lt-"
  image_id      = each.value.ami_id
  instance_type = each.value.instance_type

  tag_specifications {
    resource_type = "volume"
    tags = {
      "eks:cluster-name" = var.cluster_name
      "eks:nodegroup-name" = "${var.project_tag}-${var.environment}-${each.key}"
      Name        = "${var.project_tag}-${var.environment}-eks-${each.key}-volume"
      Project     = var.project_tag
      Environment = var.environment
      NodeGroup   = each.key
    }
  }

  tag_specifications {
    resource_type = "network-interface"
    tags = {
      "eks:cluster-name" = var.cluster_name
      "eks:nodegroup-name" = "${var.project_tag}-${var.environment}-${each.key}"
      Name        = "${var.project_tag}-${var.environment}-eks-${each.key}-eni"
      Project     = var.project_tag
      Environment = var.environment
      NodeGroup   = each.key
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      "eks:cluster-name" = var.cluster_name
      "eks:nodegroup-name" = "${var.project_tag}-${var.environment}-${each.key}"
      Name        = "${var.project_tag}-${var.environment}-eks-${each.key}-node"
      Project     = var.project_tag
      Environment = var.environment
      NodeGroup   = each.key
    }
  }

  # Per-node group user data
  user_data = base64encode(local.user_data_configs[each.key])

  network_interfaces {
    associate_public_ip_address = false
    security_groups              = [aws_security_group.nodes[each.key].id]
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"  # Forces IMDSv2
    http_put_response_hop_limit = 2
  }

  lifecycle {
    create_before_destroy = true
  }
}

# EKS Node Groups - one per configuration
resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_tag}-${var.environment}-${each.key}"
  node_role_arn   = aws_iam_role.node_group_role.arn
  subnet_ids      = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.nodes[each.key].id
    version = "$Latest"
  }

  scaling_config {
    desired_size = each.value.desired_capacity
    max_size     = each.value.max_capacity
    min_size     = each.value.min_capacity
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_registry_policy,
    aws_launch_template.nodes,
  ]

  tags = {
    Name        = "${var.project_tag}-${var.environment}-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "kubernetes-nodes"
    NodeGroup   = each.key
  }
}

# ================================
# SECURITY GROUP RULES
# ================================

# Cluster SG -> Node Group SG (Egress rules on Cluster SG) - for each node group
resource "aws_vpc_security_group_egress_rule" "cluster_to_node_kubelet" {
  for_each = var.node_groups

  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "Allow cluster to communicate with kubelet on ${each.key} nodes"
}

resource "aws_vpc_security_group_egress_rule" "cluster_to_node_ephemeral" {
  for_each = var.node_groups

  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  from_port                    = 1025
  to_port                      = 65535
  ip_protocol                  = "tcp"
  description                  = "Allow cluster to communicate with ${each.key} nodes on ephemeral ports"
}

resource "aws_vpc_security_group_egress_rule" "cluster_to_node_https" {
  for_each = var.node_groups

  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow cluster HTTPS communication to ${each.key} nodes"
}

# Node Group SG -> Cluster SG (Egress rules on Node Group SG) - for each node group
resource "aws_vpc_security_group_egress_rule" "node_to_cluster_api" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow ${each.key} nodes to communicate with cluster API"
}

# Corresponding Ingress rules on Node Group SG - for each node group
resource "aws_vpc_security_group_ingress_rule" "node_allow_cluster_kubelet" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "Allow cluster to access kubelet on ${each.key} nodes"
}

resource "aws_vpc_security_group_ingress_rule" "node_allow_cluster_ephemeral" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 1025
  to_port                      = 65535
  ip_protocol                  = "tcp"
  description                  = "Allow cluster to access ${each.key} nodes on ephemeral ports"
}

resource "aws_vpc_security_group_ingress_rule" "node_allow_cluster_https" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow cluster HTTPS access to ${each.key} nodes"
}

# Corresponding Ingress rules on Cluster SG - for each node group
resource "aws_vpc_security_group_ingress_rule" "cluster_allow_node_api" {
  for_each = var.node_groups

  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow ${each.key} nodes to access cluster API"
}

# Node Group to Node Group allow all - WITHIN same group
resource "aws_vpc_security_group_egress_rule" "node_to_node_same_group" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  ip_protocol                  = "-1"  # All protocols
  description                  = "Allow all communication between nodes in the same ${each.key} group"
}

resource "aws_vpc_security_group_ingress_rule" "node_to_node_same_group" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  ip_protocol                  = "-1"  # All protocols
  description                  = "Allow all communication between nodes in the same ${each.key} group"
}



# Cross-NodeGroup Ingress: Allow all communication from other node groups
# Cross-NodeGroup Egress: Allow all communication to other node groups  
resource "aws_vpc_security_group_egress_rule" "cross_nodegroup_communication" {
  for_each = {
    for pair in local.node_group_pairs : "${pair.source}-to-${pair.target}" => pair
  }

  security_group_id            = aws_security_group.nodes[each.value.source].id
  referenced_security_group_id = aws_security_group.nodes[each.value.target].id
  ip_protocol                  = "-1"  # All protocols
  description                  = "Allow all communication from ${each.value.source} nodes to ${each.value.target} nodes"
}

resource "aws_vpc_security_group_ingress_rule" "cross_nodegroup_communication" {
  for_each = {
    for pair in local.node_group_pairs : "${pair.source}-to-${pair.target}" => pair
  }

  security_group_id            = aws_security_group.nodes[each.value.target].id
  referenced_security_group_id = aws_security_group.nodes[each.value.source].id
  ip_protocol                  = "-1"  # All protocols
  description                  = "Allow all communication from ${each.value.source} nodes to ${each.value.target} nodes"
}

# External access to cluster API
resource "aws_vpc_security_group_ingress_rule" "eks_api_from_cidrs" {
  for_each = toset(var.eks_api_allowed_cidr_blocks)

  security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "Allow access to EKS API from CIDR ${each.value}"
}

# Internet egress rules - apply to ALL node groups
resource "aws_vpc_security_group_egress_rule" "nodes_dns_udp" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "Allow DNS resolution (UDP) from ${each.key} nodes"
  
  ip_protocol = "udp"
  from_port   = 53
  to_port     = 53
  cidr_ipv4   = "0.0.0.0/0"
}

# DNS resolution (TCP) - some DNS queries use TCP
resource "aws_vpc_security_group_egress_rule" "nodes_dns_tcp" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "Allow DNS resolution (TCP) from ${each.key} nodes"
  
  ip_protocol = "tcp"
  from_port   = 53
  to_port     = 53
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "nodes_https_outbound" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "Allow HTTPS outbound for AWS APIs from ${each.key} nodes"
  
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "nodes_http_outbound" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "Allow HTTP outbound for package updates from ${each.key} nodes"
  
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "nodes_ntp" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "Allow NTP for time synchronization from ${each.key} nodes"
  
  ip_protocol = "udp"
  from_port   = 123
  to_port     = 123
  cidr_ipv4   = "0.0.0.0/0"
}

# Full outbound internet access
resource "aws_vpc_security_group_egress_rule" "nodes_all_outbound" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "Allow all outbound traffic from ${each.key} nodes"
  
  ip_protocol = "-1"  # All protocols
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Name = "${var.project_tag}-${var.environment}-${each.key}-all-outbound"
  }
}

# Ephemeral ports for outbound connections
resource "aws_vpc_security_group_egress_rule" "nodes_ephemeral_tcp" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "Allow outbound TCP ephemeral ports from ${each.key} nodes"
  
  ip_protocol = "tcp"
  from_port   = 1024
  to_port     = 65535
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Name = "${var.project_tag}-${var.environment}-${each.key}-ephemeral-tcp"
  }
}

# Custom ports that some services might use
resource "aws_vpc_security_group_egress_rule" "nodes_custom_ports" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "Allow outbound for custom application ports from ${each.key} nodes"
  
  ip_protocol = "tcp"
  from_port   = 8000
  to_port     = 8999
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Name = "${var.project_tag}-${var.environment}-${each.key}-custom-ports"
  }
}


# # Get the default node security group created by EKS
# data "aws_security_group" "node_group_sg" {
#   filter {
#     name   = "group-name"
#     values = ["eks-cluster-sg-${aws_eks_cluster.main.name}-*"]
#   }
  
#   filter {
#     name   = "tag:aws:eks:cluster-name"
#     values = [aws_eks_cluster.main.name]
#   }

#   filter {
#     name   = "vpc-id"
#     values = [var.vpc_id]
#   }
# }

# Cluster SG
# resource "aws_security_group" "eks_cluster" {
#   name        = "${var.project_tag}-${var.environment}-eks-cluster-sg"
#   description = "Custom EKS cluster security group"
#   vpc_id      = var.vpc_id

#   tags = {
#     Name        = "${var.project_tag}-${var.environment}-eks-cluster-sg"
#     Project     = var.project_tag
#     Environment = var.environment
#     Purpose     = "eks-cluster-api"
#   }
# }

# # Create IAM instance profile for the node group
# resource "aws_iam_instance_profile" "nodes" {
#   name = "${var.project_tag}-${var.environment}-eks-nodes-instance-profile"
#   role = aws_iam_role.node_group_role.name
  
#   tags = {
#     Name = "${var.project_tag}-${var.environment}-eks-nodes-instance-profile"
#   }
# }

# # Control Plane access to the nodes
# resource "aws_security_group_rule" "allow_cluster_to_nodes" {
#   type                     = "ingress"
#   from_port                = 1025
#   to_port                  = 65535
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.nodes.id
#   source_security_group_id = "sg-0a9d986ac63a06d9f"
#   description              = "Allow control plane to reach kubelet"
# }
