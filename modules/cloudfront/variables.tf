# modules/cloudfront/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket to serve content from"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  type        = string
}

variable "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  type        = string
}

variable "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL to associate with CloudFront"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS"
  type        = string
}

variable "domain" {
  description = "Full domain name (subdomain.domain)"
  type        = string
}

variable "json_view_base_domain_name" {
  description = "Full JSON viewer domain name"
  type        = string
}

# variable "default_root_object" {
#   description = "Default root object for CloudFront"
#   type        = string
#   default     = "index.html"
# }
