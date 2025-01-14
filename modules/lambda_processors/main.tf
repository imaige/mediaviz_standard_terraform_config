# lambda_processors/main.tf

locals {
  lambda_functions = {
    "l-blur-model"               = "blur_model_processing"
    "l-colors-model"             = "colors_model_processing"
    "l-image-comparison-model"   = "image_comparison_model_processing"
    "l-facial-recognition-model" = "face_recognition_model_processing"

  }
}

resource "aws_lambda_function" "processor" {
  for_each = local.lambda_functions

  function_name = "${var.project_name}-${var.env}-${each.key}"
  role         = aws_iam_role.processor_role_new[each.key].arn
  
  package_type = "Image"
  image_uri    = "${var.ecr_repository_url}-${each.key}:latest"

  memory_size = var.memory_size
  timeout     = var.timeout

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.processor_sg[each.key].id]
  }

  environment {
    variables = {
      ENVIRONMENT     = var.env
      DB_SECRET_ARN   = var.aurora_secret_arn
      DB_CLUSTER_ARN  = var.aurora_cluster_arn
      DB_NAME         = var.aurora_database_name
    }
  }

  dead_letter_config {
    target_arn = var.dlq_arn
  }

  tracing_config {
    mode = "Active"
  }

  # Use only standard_tags + model
  tags = {
    name        = "${var.project_name}-${var.env}-${each.key}"
    environment = var.env
  }

  lifecycle {
    create_before_destroy = true
    replace_triggered_by = [
      aws_security_group.processor_sg[each.key]
    ]
  }

  depends_on = [aws_iam_role.processor_role_new]
}

resource "aws_security_group" "processor_sg" {
  for_each = local.lambda_functions

  name        = "${var.project_name}-${var.env}-${each.key}-sg"
  description = "Security group for ${each.key} Lambda processor"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = "Aurora access"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.aurora_security_group_id]
  }

  # Use only standard_tags + model
  tags = {
    name        = "${var.project_name}-${var.env}-${each.key}"
    environment = var.env
  }

  # Add lifecycle policy to help with deletion
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "processor_role_new" {
  for_each = local.lambda_functions

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

  # tags = {
  #   name        = "${var.project_name}-${var.env}-${each.key}"
  #   environment = var.env
  # }
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  for_each = local.lambda_functions

  role       = aws_iam_role.processor_role_new[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  for_each = local.lambda_functions

  role       = aws_iam_role.processor_role_new[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "sqs_policy" {
  for_each = local.lambda_functions

  name = "${var.project_name}-${var.env}-${each.key}-sqs-policy"
  role = aws_iam_role.processor_role_new[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = var.sqs_queues[each.key]  # Changed from var.sqs_queue_arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl"
        ]
        Resource = var.dlq_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "aurora_policy" {
  for_each = local.lambda_functions

  name = "${var.project_name}-${var.env}-${each.key}-aurora-policy"
  role = aws_iam_role.processor_role_new[each.key].id

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

resource "aws_iam_role_policy" "ecr_policy" {
  for_each = local.lambda_functions

  name = "${var.project_name}-${var.env}-${each.key}-ecr-policy"
  role = aws_iam_role.processor_role_new[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = var.ecr_repository_arns
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_policy" {
  for_each = local.lambda_functions

  name = "${var.project_name}-${var.env}-${each.key}-s3-policy"
  role = aws_iam_role.processor_role_new[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetObjectVersion",
          "s3:ListAllMyBuckets"
        ]
        Resource = [
          "arn:aws:s3:::*",
          "arn:aws:s3:::*/*"
        ]
      }
    ]
  })
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  for_each = local.lambda_functions

  event_source_arn = var.sqs_queues[each.key]
  function_name    = aws_lambda_function.processor[each.key].arn
  batch_size       = 1
  maximum_batching_window_in_seconds = 0
  
  scaling_config {
    maximum_concurrency = 2
  }

  function_response_types = ["ReportBatchItemFailures"]
}

resource "aws_iam_role_policy" "rekognition_policy" {
  for_each = local.lambda_functions

  name = "${var.project_name}-${var.env}-${each.key}-rekognition-policy"
  role = aws_iam_role.processor_role_new[each.key].id  # Changed from processor_role to processor_role_new

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rekognition:DetectFaces"
        ]
        Resource = "*"
      }
    ]
  })
}