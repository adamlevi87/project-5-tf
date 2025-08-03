# modules/eks/main.tf

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

# Attach required policies to node group role
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
    #security_group_ids = [aws_security_group.eks_cluster.id]
    #security_group_ids = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.eks_api_allowed_cidr_blocks
  }

  enabled_cluster_log_types = var.cluster_enabled_log_types

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_cloudwatch_log_group.cluster_logs,
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

# Node group SG
resource "aws_security_group" "nodes" {
  name        = "${var.project_tag}-${var.environment}-eks-node-group-sg"
  description = "EKS worker node SG"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_tag}-${var.environment}-eks-node-group-sg"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "eks-worker-nodes"
  }
}

data "aws_ami" "eks_default" {
  most_recent = true
  owners      = ["602401143452"]  # Amazon EKS AMI owner (official)
  
  filter {
    name   = "name"
    values = ["amazon-eks-node-*-x86_64-*"]
  }
}

# # Create IAM instance profile for the node group
# resource "aws_iam_instance_profile" "nodes" {
#   name = "${var.project_tag}-${var.environment}-eks-nodes-instance-profile"
#   role = aws_iam_role.node_group_role.name
  
#   tags = {
#     Name = "${var.project_tag}-${var.environment}-eks-nodes-instance-profile"
#   }
# }

resource "aws_launch_template" "nodes" {
  name_prefix   = "${var.project_tag}-${var.environment}-eks-nodes-lt-"
  image_id      = data.aws_ami.eks_default.image_id
  instance_type = var.node_group_instance_types[0]

  # iam_instance_profile {
  #   name = aws_iam_instance_profile.nodes.name
  # }

  # Add the required user data for EKS bootstrap
  user_data = base64encode(templatefile("${path.module}/nodeadm-config.yaml", {
    cluster_name        = aws_eks_cluster.main.name
    cluster_endpoint    = aws_eks_cluster.main.endpoint
    cluster_ca          = aws_eks_cluster.main.certificate_authority[0].data
    cluster_cidr        = aws_eks_cluster.main.kubernetes_network_config[0].service_ipv4_cidr
  }))

  network_interfaces {
    associate_public_ip_address = false
    security_groups              = [aws_security_group.nodes.id]
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

# EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_tag}-${var.environment}-node-group"
  node_role_arn   = aws_iam_role.node_group_role.arn
  subnet_ids      = var.private_subnet_ids

  #instance_types  = var.node_group_instance_types

  launch_template {
    id      = aws_launch_template.nodes.id
    version = "$Latest"
  }

  scaling_config {
    desired_size = var.node_group_desired_capacity
    max_size     = var.node_group_max_capacity
    min_size     = var.node_group_min_capacity
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
    Name        = "${var.project_tag}-${var.environment}-node-group"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "kubernetes-nodes"
  }
}

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



# Cluster SG -> Node Group SG (Egress rules on Cluster SG)
resource "aws_vpc_security_group_egress_rule" "cluster_to_node_kubelet" {
  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.nodes.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "Allow cluster to communicate with kubelet on nodes"
}

resource "aws_vpc_security_group_egress_rule" "cluster_to_node_ephemeral" {
  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.nodes.id
  from_port                    = 1025
  to_port                      = 65535
  ip_protocol                  = "tcp"
  description                  = "Allow cluster to communicate with nodes on ephemeral ports"
}

resource "aws_vpc_security_group_egress_rule" "cluster_to_node_https" {
  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.nodes.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow cluster HTTPS communication to nodes"
}

# Node Group SG -> Cluster SG (Egress rules on Node Group SG)
resource "aws_vpc_security_group_egress_rule" "node_to_cluster_api" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow nodes to communicate with cluster API"
}

# Corresponding Ingress rules on Node Group SG
resource "aws_vpc_security_group_ingress_rule" "node_allow_cluster_kubelet" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "Allow cluster to access kubelet on nodes"
}

resource "aws_vpc_security_group_ingress_rule" "node_allow_cluster_ephemeral" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 1025
  to_port                      = 65535
  ip_protocol                  = "tcp"
  description                  = "Allow cluster to access nodes on ephemeral ports"
}

resource "aws_vpc_security_group_ingress_rule" "node_allow_cluster_https" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow cluster HTTPS access to nodes"
}

# Corresponding Ingress rules on Cluster SG
resource "aws_vpc_security_group_ingress_rule" "cluster_allow_node_api" {
  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.nodes.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow nodes to access cluster API"
}

# Node Group to Node Group allow all
resource "aws_vpc_security_group_ingress_rule" "node_to_node_all" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.nodes.id
  ip_protocol                  = "-1"  # All protocols
  description                  = "Allow all communication between nodes in the same group"
}

resource "aws_vpc_security_group_egress_rule" "node_to_node_all" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.nodes.id
  ip_protocol                  = "-1"  # All protocols
  description                  = "Allow all communication between nodes in the same group"
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

# DNS resolution (UDP)
resource "aws_vpc_security_group_egress_rule" "nodes_dns_udp" {
  security_group_id = aws_security_group.nodes.id
  description       = "Allow DNS resolution (UDP)"
  
  ip_protocol = "udp"
  from_port   = 53
  to_port     = 53
  cidr_ipv4   = "0.0.0.0/0"
}

# DNS resolution (TCP) - some DNS queries use TCP
resource "aws_vpc_security_group_egress_rule" "nodes_dns_tcp" {
  security_group_id = aws_security_group.nodes.id
  description       = "Allow DNS resolution (TCP)"
  
  ip_protocol = "tcp"
  from_port   = 53
  to_port     = 53
  cidr_ipv4   = "0.0.0.0/0"

}

resource "aws_vpc_security_group_egress_rule" "nodes_https_outbound" {
  security_group_id = aws_security_group.nodes.id
  description       = "Allow HTTPS outbound for AWS APIs"
  
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "nodes_http_outbound" {
  security_group_id = aws_security_group.nodes.id
  description       = "Allow HTTP outbound for package updates"
  
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "nodes_ntp" {
  security_group_id = aws_security_group.nodes.id
  description       = "Allow NTP for time synchronization"
  
  ip_protocol = "udp"
  from_port   = 123
  to_port     = 123
  cidr_ipv4   = "0.0.0.0/0"
}

# Option 1: Full outbound internet access (simplest approach)
resource "aws_vpc_security_group_egress_rule" "nodes_all_outbound" {
  security_group_id = aws_security_group.nodes.id
  description       = "Allow all outbound traffic"
  
  ip_protocol = "-1"  # All protocols
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Name = "${var.project_tag}-${var.environment}-nodes-all-outbound"
  }
}

# Option 2: If you prefer more restrictive (covers most EKS needs)
# Use the individual rules I provided earlier PLUS these additional ones:

# Ephemeral ports for outbound connections
resource "aws_vpc_security_group_egress_rule" "nodes_ephemeral_tcp" {
  security_group_id = aws_security_group.nodes.id
  description       = "Allow outbound TCP ephemeral ports"
  
  ip_protocol = "tcp"
  from_port   = 1024
  to_port     = 65535
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Name = "${var.project_tag}-${var.environment}-nodes-ephemeral-tcp"
  }
}

# Custom ports that some services might use
resource "aws_vpc_security_group_egress_rule" "nodes_custom_ports" {
  security_group_id = aws_security_group.nodes.id
  description       = "Allow outbound for custom application ports"
  
  ip_protocol = "tcp"
  from_port   = 8000
  to_port     = 8999
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Name = "${var.project_tag}-${var.environment}-nodes-custom-ports"
  }
}