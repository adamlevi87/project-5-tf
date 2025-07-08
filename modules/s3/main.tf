# modules/s3/main.tf

resource "aws_s3_bucket" "app_data" {
  bucket = "${var.project_tag}-${var.environment}-app-data-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.project_tag}-${var.environment}-app-data"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "application-data"
  }
}

# Random suffix to ensure bucket name uniqueness
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Enable versioning
resource "aws_s3_bucket_versioning" "app_data_versioning" {
  bucket = aws_s3_bucket.app_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "app_data_encryption" {
  bucket = aws_s3_bucket.app_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "app_data_pab" {
  bucket = aws_s3_bucket.app_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "app_data_lifecycle" {
  count  = var.enable_lifecycle_policy ? 1 : 0
  bucket = aws_s3_bucket.app_data.id

  rule {
    id     = "app_data_lifecycle"
    status = "Enabled"

    # Move to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Move to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Delete after specified retention period
    dynamic "expiration" {
      for_each = var.data_retention_days > 0 ? [1] : []
      content {
        days = var.data_retention_days
      }
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# IAM policy for lambda access
resource "aws_iam_policy" "lambda_s3_access" {
  name        = "${var.project_tag}-${var.environment}-lambda-s3-access"
  description = "IAM policy for Lambda to access S3 app data bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.app_data.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.app_data.arn
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-lambda-s3-policy"
    Project     = var.project_tag
    Environment = var.environment
  }
}