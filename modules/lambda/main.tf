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
      # ENCRYPTED_ENV_VAR = var.encrypted_env_var
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

resource "aws_iam_role_policy" "lambda_dlq_policy" {
  name = "${var.project_name}-${var.env}-lambda-dlq-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.lambda_dlq.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda Module main.tf

locals {
  lambda_functions = ["module1", "module2", "module3"]
}

# Create Lambda functions
resource "aws_lambda_function" "processor" {
  for_each = toset(local.lambda_functions)

  filename         = data.archive_file.lambda_package[each.key].output_path
  function_name    = "${var.project_name}-${var.env}-${each.key}-processor"
  role            = aws_iam_role.lambda_role[each.key].arn
  handler         = "handler.handle_processing"
  runtime         = var.lambda_runtime
  memory_size     = var.memory_size
  timeout         = var.timeout

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda_sg[each.key].id]
  }

  environment {
    variables = {
      ENVIRONMENT = var.env
      DB_SECRET_ARN = var.aurora_secret_arn
      DB_CLUSTER_ARN = var.aurora_cluster_arn
      DB_NAME = var.aurora_database_name
    }
  }

  dead_letter_config {
    target_arn = var.dlq_arn
  }

  tracing_config {
    mode = "Active"
  }

  tags = merge(var.tags, {
    Environment = var.env
    Module      = each.key
    Terraform   = "true"
  })
}

# Lambda deployment packages
data "archive_file" "lambda_package" {
  for_each = toset(local.lambda_functions)

  type        = "zip"
  source_dir  = "${path.module}/functions/${each.key}"
  output_path = "${path.module}/dist/${each.key}.zip"
}

# IAM roles for Lambda functions
resource "aws_iam_role" "lambda_role" {
  for_each = toset(local.lambda_functions)

  name = "${var.project_name}-${var.env}-${each.key}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Security Groups for Lambda functions
resource "aws_security_group" "lambda_sg" {
  for_each = toset(local.lambda_functions)

  name        = "${var.project_name}-${var.env}-${each.key}-sg"
  description = "Security group for ${each.key} Lambda function"
  vpc_id      = var.vpc_id

  # Allow outbound HTTPS
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow Aurora access
  egress {
    description = "Aurora access"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [var.aurora_security_group_id]
  }

  tags = merge(var.tags, {
    Environment = var.env
    Module      = each.key
    Terraform   = "true"
  })
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "basic_execution" {
  for_each = toset(local.lambda_functions)

  role       = aws_iam_role.lambda_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC access policy
resource "aws_iam_role_policy_attachment" "vpc_access" {
  for_each = toset(local.lambda_functions)

  role       = aws_iam_role.lambda_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# SQS processing policy
resource "aws_iam_role_policy" "sqs_policy" {
  for_each = toset(local.lambda_functions)

  name = "${var.project_name}-${var.env}-${each.key}-sqs-policy"
  role = aws_iam_role.lambda_role[each.key].id

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

# Aurora access policy
resource "aws_iam_role_policy" "aurora_policy" {
  for_each = toset(local.lambda_functions)

  name = "${var.project_name}-${var.env}-${each.key}-aurora-policy"
  role = aws_iam_role.lambda_role[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement",
          "rds-data:BeginTransaction",
          "rds-data:CommitTransaction",
          "rds-data:RollbackTransaction"
        ]
        Resource = var.aurora_cluster_arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.aurora_secret_arn
      }
    ]
  })
}

# SQS triggers for Lambda functions
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  for_each = toset(local.lambda_functions)

  event_source_arn = var.sqs_queue_arn
  function_name    = aws_lambda_function.processor[each.key].arn
  batch_size       = 1
  maximum_batching_window_in_seconds = 0
}