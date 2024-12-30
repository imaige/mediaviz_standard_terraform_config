data "archive_file" "lambda_package" {
  type        = "zip"
  source_dir  = "${path.module}/functions/image_upload"
  output_path = "${path.module}/dist/image_upload.zip"
}

resource "aws_lambda_function" "image_upload" {
  filename      = data.archive_file.lambda_package.output_path
  function_name = "${var.project_name}-${var.env}-image-upload"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.handle_upload"
  runtime       = var.lambda_runtime
  memory_size   = var.memory_size
  timeout       = var.timeout

  # VPC configuration
  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  # Environment variables should be here in the main function resource
  environment {
    variables = {
      BUCKET_NAME       = var.s3_bucket_name
      ENCRYPTED_ENV_VAR = var.encrypted_env_var
    }
  }
  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }  

  kms_key_arn = var.kms_key_arn
  code_signing_config_arn = aws_lambda_code_signing_config.signing_config.arn

  # Enable X-Ray tracing
  tracing_config {
    mode = "Active"
  }

  reserved_concurrent_executions = 100  # Add directly to function
  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })

}

# Create function URL configuration as a separate resource
resource "aws_lambda_function_url" "image_upload" {
  function_name      = aws_lambda_function.image_upload.function_name
  authorization_type = "AWS_IAM"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["POST"]
    allow_headers     = ["*"]
    expose_headers    = ["*"]
    max_age           = 3600
  }
}

# X-Ray tracing configuration
resource "aws_lambda_function_event_invoke_config" "image_upload" {
  function_name = aws_lambda_function.image_upload.function_name

  destination_config {
    on_failure {
      destination = aws_sqs_queue.lambda_dlq.arn
    }
  }

  maximum_retry_attempts = 0
}

# Code signing configuration
resource "aws_lambda_code_signing_config" "signing_config" {
  allowed_publishers {
    signing_profile_version_arns = [var.signing_profile_version_arn]
  }

  policies {
    untrusted_artifact_on_deployment = "Enforce"
  }
}

# Create DLQ for Lambda
resource "aws_sqs_queue" "lambda_dlq" {
  name = "${var.project_name}-${var.env}-lambda-dlq"
  kms_master_key_id = var.kms_key_id
}

# Create security group for Lambda
resource "aws_security_group" "lambda_sg" {
  name        = "${var.project_name}-${var.env}-lambda-sg"
  description = "Security group for Lambda function"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS outbound traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP outbound traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.env
    Terraform   = "true"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-${var.env}-lambda-role"

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
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_eventbridge_policy" {
  name = "${var.project_name}-${var.env}-image-upload-eventbridge-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "processor_package" {
  type        = "zip"
  source_dir  = "${path.module}/functions/image_processor"
  output_path = "${path.module}/dist/image_processor.zip"
}

resource "aws_lambda_function" "image_processor" {
  filename         = data.archive_file.processor_package.output_path
  function_name    = "${var.project_name}-${var.env}-image-processor"
  role            = aws_iam_role.processor_role.arn
  handler         = "handler.handle_processing"
  runtime         = var.lambda_runtime
  memory_size     = var.memory_size
  timeout         = var.timeout

  environment {
    variables = {
      OUTPUT_BUCKET = var.output_bucket_name
      SOURCE_BUCKET = var.s3_bucket_name
    }
  }

  tags = var.tags
}

# IAM role for Processor Lambda
resource "aws_iam_role" "processor_role" {
  name = "${var.project_name}-${var.env}-image-processor-role"

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
}

# IAM policy for S3 access (both read and write)
resource "aws_iam_role_policy" "processor_s3_policy" {
  name = "${var.project_name}-${var.env}-image-processor-s3-policy"
  role = aws_iam_role.processor_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "${var.s3_bucket_arn}/*",
          "${var.output_bucket_arn}/*"
        ]
      }
    ]
  })
}

# CloudWatch Logs policy
resource "aws_iam_role_policy_attachment" "processor_logs" {
  role       = aws_iam_role.processor_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# SQS policy
resource "aws_iam_role_policy" "processor_sqs_policy" {
  name = "${var.project_name}-${var.env}-image-processor-sqs-policy"
  role = aws_iam_role.processor_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

# SQS trigger for Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.sqs_queue_arn
  function_name    = aws_lambda_function.image_processor.arn
  batch_size       = 1
}