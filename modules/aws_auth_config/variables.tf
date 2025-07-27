# modules/aws_auth_config/variables.tf

variable "map_roles" {
  description = "List of IAM roles to map to Kubernetes RBAC"
  type        = list(any)
  default     = []
}

variable "eks_user_access_map" {
  description = "Map of IAM users and their RBAC group mappings"
  type = map(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = {}
}

variable "eks_dependency" {
  description = "Dependency to ensure EKS cluster is created first"
  type        = any
}
