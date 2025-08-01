variable "cert_domain_name" {
  type        = string
  description = "Fully qualified domain name (FQDN) for the SSL certificate (e.g., chatbot.yourdomain.com)"
}

variable "route53_zone_id" {
  type        = string
  description = "ID of the Route53 hosted zone used for DNS validation"
}

variable "project_tag" {
  type        = string
  description = "Tag to identify project resources"
}

variable "environment" {
  type        = string
  description = "Deployment environment (e.g., dev, prod)"
}

variable "route53_depends_on" {
  description = "Used to enforce a dependency on Route53 zone creation"
  type        = string
}