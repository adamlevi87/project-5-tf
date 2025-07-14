# modules/ecr/outputs.tf

output "repository_url" {
  value       = aws_ecr_repository.this.repository_url
  description = "The URL of the ECR repository"
}

output "repository_name" {
  value       = aws_ecr_repository.this.name
  description = "The URL of the ECR repository"
}

# output "repository_arn" {
#   value       = aws_ecr_repository.this.arn
#   description = "The ARN of the ECR repository"
# }