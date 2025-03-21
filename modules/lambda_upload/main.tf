locals {
  # Normalize tags to lowercase to prevent case-sensitivity issues
  normalized_tags = merge(
    {
      for key, value in var.tags :
      lower(key) => value
    },
    {
      environment = var.env
      terraform   = "true"
    }
  )
}

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

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      BUCKET_NAME        = var.s3_bucket_name
      DB_SECRET_ARN     = var.aurora_secret_arn    # Add this
      DB_CLUSTER_ARN    = var.aurora_cluster_arn   # Add this
      DB_NAME           = var.aurora_database_name  # Add this
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }  

  kms_key_arn = var.kms_key_arn
#   code_signing_config_arn = aws_lambda_code_signing_config.signing_config.arn

  tracing_config {
    mode = "Active"
  }

  reserved_concurrent_executions = null

  tags = merge(local.normalized_tags, {
    environment = var.env
    terraform   = "true"
  })
}

resource "aws_lambda_function_url" "image_upload" {
  function_name      = aws_lambda_function.image_upload.function_name
  authorization_type = "AWS_IAM"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["POST"]
    allow_headers     = ["*"]
    expose_headers    = ["*"]
    max_age          = 3600
  }
}

resource "aws_lambda_function_event_invoke_config" "image_upload" {
  function_name = aws_lambda_function.image_upload.function_name

  destination_config {
    on_failure {
      destination = aws_sqs_queue.lambda_dlq.arn
    }
  }

  maximum_retry_attempts = 0
}

resource "aws_signer_signing_profile" "lambda_signing" {
  name_prefix = replace("${substr(var.project_name, 0, 20)}${var.env}", "-", "")
  platform_id = "AWSLambda-SHA384-ECDSA"

  tags = merge(local.normalized_tags, {
    environment = var.env
    terraform   = "true"
  })
}

resource "aws_lambda_code_signing_config" "signing_config" {
  allowed_publishers {
    signing_profile_version_arns = [aws_signer_signing_profile.lambda_signing.version_arn]
  }

  policies {
    untrusted_artifact_on_deployment = "Enforce"
  }

  description = "Code signing configuration for ${var.project_name}-${var.env}"
}

resource "aws_sqs_queue" "lambda_dlq" {
  name = "${var.project_name}-${var.env}-lambda-dlq"
  kms_master_key_id = var.kms_key_id

  tags = merge(local.normalized_tags, {
    environment = var.env
    terraform   = "true"
  })
}

resource "aws_security_group" "lambda_sg" {
  name        = "${var.project_name}-${var.env}-lambda-sg-new"
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

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.normalized_tags, {
    environment = var.env
    terraform   = "true"
  })
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-${var.env}-lambda-role-new"

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

#   tags = merge( {
#     environment = "dev-new1"
#   })
}

resource "aws_iam_role_policy" "lambda_rds_policy" {
  name = "${var.project_name}-${var.env}-lambda-rds-policy"
  role = aws_iam_role.lambda_role.id

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

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "${var.project_name}-${var.env}-lambda-s3-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::*",
          "arn:aws:s3:::*/*"
        ]
      }
    ]
  })
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

resource "aws_iam_role_policy" "lambda_kms_policy" {
  name = "${var.project_name}-${var.env}-lambda-kms-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.aurora_kms_key_arn  # You'll need to pass this from your Aurora module
      }
    ]
  })
}