# modules/lambda/main.tf

# Install npm dependencies before creating zip
resource "null_resource" "npm_install" {
  triggers = {
    package_json = filebase64("${var.lambda_source_dir}/package.json")
  }

  provisioner "local-exec" {
    command = "cd ${var.lambda_source_dir} && npm install"
  }
}

# Create zip file from source code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.lambda_source_dir
  output_path = "./lambda-deployment.zip"
  
  depends_on = [null_resource.npm_install]
}

# Lambda function
resource "aws_lambda_function" "message_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_tag}-${var.environment}-${var.function_name}"
  role            = aws_iam_role.lambda_role.arn
  handler         = var.handler
  runtime         = var.runtime
  timeout         = var.timeout
  memory_size     = var.memory_size

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = merge({
      ENVIRONMENT = var.environment
      PROJECT_TAG = var.project_tag
      S3_BUCKET   = var.s3_bucket_name
    }, var.environment_variables)
  }

  tags = {
    Name        = "${var.project_tag}-${var.environment}-${var.function_name}"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "message-processing"
  }
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_tag}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-lambda-role"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "lambda-execution"
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
        Resource = "${var.s3_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "${var.s3_bucket_arn}"
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-lambda-s3-policy"
    Project     = var.project_tag
    Environment = var.environment
  }
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach SQS access policy (from SQS module)
resource "aws_iam_role_policy_attachment" "lambda_sqs_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = var.sqs_lambda_policy_arn
}

# Attach S3 access policy (from S3 module)
resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_access.arn
}

# Event Source Mapping to connect SQS to Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.sqs_queue_arn
  function_name    = aws_lambda_function.message_processor.arn
  
  batch_size                         = var.batch_size
  maximum_batching_window_in_seconds = var.maximum_batching_window_in_seconds
  
  # Configure scaling
  scaling_config {
    maximum_concurrency = var.maximum_concurrency
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_sqs_access,
    aws_iam_role_policy_attachment.lambda_basic,
  ]
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.message_processor.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_tag}-${var.environment}-lambda-logs"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "lambda-logging"
  }
}
