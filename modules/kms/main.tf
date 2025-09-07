# modules/kms/main.tf

# KMS Key for S3 bucket encryption
resource "aws_kms_key" "s3_key" {
  description             = "KMS key for ${var.project_tag} ${var.environment} S3 bucket encryption"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

  tags = {
    Name        = "${var.project_tag}-${var.environment}-s3-kms-key"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "s3-encryption"
  }
}

# KMS Alias for easier identification
resource "aws_kms_alias" "s3_key_alias" {
  name          = "alias/${var.project_tag}-${var.environment}-s3-encryption"
  target_key_id = aws_kms_key.s3_key.key_id
}

# IAM role for KMS key management
resource "aws_iam_role" "kms_key_role" {
  name = "${var.project_tag}-${var.environment}-kms-key-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-kms-key-role"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "kms-key-management"
  }
}

# IAM policy for KMS key administration
resource "aws_iam_policy" "kms_key_admin_policy" {
  name        = "${var.project_tag}-${var.environment}-kms-key-admin"
  description = "IAM policy for KMS key administration"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ]
        Resource = aws_kms_key.s3_key.arn
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-kms-key-admin-policy"
    Project     = var.project_tag
    Environment = var.environment
  }
}

# IAM policy for S3 service to use the key
resource "aws_iam_policy" "kms_s3_policy" {
  name        = "${var.project_tag}-${var.environment}-kms-s3-access"
  description = "IAM policy for S3 service to use KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = aws_kms_key.s3_key.arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = var.s3_bucket_arn
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-kms-s3-policy"
    Project     = var.project_tag
    Environment = var.environment
  }
}

# IAM policy for Lambda service to use the key
resource "aws_iam_policy" "kms_lambda_policy" {
  name        = "${var.project_tag}-${var.environment}-kms-lambda-access"
  description = "IAM policy for Lambda service to use KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = aws_kms_key.s3_key.arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = var.lambda_function_arn
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-kms-lambda-policy"
    Project     = var.project_tag
    Environment = var.environment
  }
}

# IAM policy for CloudFront service to use the key
resource "aws_iam_policy" "kms_cloudfront_policy" {
  name        = "${var.project_tag}-${var.environment}-kms-cloudfront-access"
  description = "IAM policy for CloudFront service to use KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-kms-cloudfront-policy"
    Project     = var.project_tag
    Environment = var.environment
  }
}

# Attach admin policy to role
resource "aws_iam_role_policy_attachment" "kms_admin_attachment" {
  role       = aws_iam_role.kms_key_role.name
  policy_arn = aws_iam_policy.kms_key_admin_policy.arn
}

# Attach S3 policy to role
resource "aws_iam_role_policy_attachment" "kms_s3_attachment" {
  role       = aws_iam_role.kms_key_role.name
  policy_arn = aws_iam_policy.kms_s3_policy.arn
}

# Attach Lambda policy to role
resource "aws_iam_role_policy_attachment" "kms_lambda_attachment" {
  role       = aws_iam_role.kms_key_role.name
  policy_arn = aws_iam_policy.kms_lambda_policy.arn
}

# Attach CloudFront policy to role
resource "aws_iam_role_policy_attachment" "kms_cloudfront_attachment" {
  role       = aws_iam_role.kms_key_role.name
  policy_arn = aws_iam_policy.kms_cloudfront_policy.arn
}
