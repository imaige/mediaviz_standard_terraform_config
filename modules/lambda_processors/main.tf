# lambda_processors/main.tf

locals {
  lambda_functions = {
    "l-blur-model"               = "blur_model"
    "l-colors-model"             = "colors_model"
    "l-image-comparison-model"   = "image_comparison_model"
    "l-facial-recognition-model" = "face_recognition_model"
  }
  
  # Normalize tags for consistency
  normalized_tags = merge(var.tags, {
    Environment = var.env
    Project     = var.project_name
    ManagedBy   = "terraform"
  })
  
  # Use shared repository URL if provided, else use account's own
  repository_base_url = var.shared_ecr_repository_url != "" ? var.shared_ecr_repository_url : var.ecr_repository_url
}

resource "aws_lambda_function" "processor" {
  for_each = local.lambda_functions

  function_name = "${var.project_name}-${var.env}-${each.key}"
  role          = aws_iam_role.processor_role[each.key].arn
  
  package_type = "Image"
  image_uri    = "${local.repository_base_url}-${each.key}:latest"

  memory_size = var.memory_size
  timeout     = var.timeout
  
  # Optional reserved concurrency
  reserved_concurrent_executions = var.reserved_concurrency > 0 ? var.reserved_concurrency : null

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.processor_sg[each.key].id]
  }

  environment {
    variables = merge({
      ENVIRONMENT     = var.env
      DB_SECRET_ARN   = var.aurora_secret_arn
      DB_CLUSTER_ARN  = var.aurora_cluster_arn
      DB_NAME         = var.aurora_database_name
      MODEL_TYPE      = each.value
      AWS_REGION      = var.aws_region
    }, var.additional_environment_variables)
  }

  dead_letter_config {
    target_arn = var.dlq_arn
  }

  tracing_config {
    mode = "Active"
  }

  tags = merge(local.normalized_tags, {
    Name    = "${var.project_name}-${var.env}-${each.key}"
    Model   = each.key
    Service = "lambda-processor"
  })

  lifecycle {
    create_before_destroy = true
    replace_triggered_by = [
      aws_security_group.processor_sg[each.key]
    ]
  }

  depends_on = [aws_iam_role.processor_role]
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

  tags = merge(local.normalized_tags, {
    Name  = "${var.project_name}-${var.env}-${each.key}-sg"
    Model = each.key
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "processor_role" {
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

  tags = merge(local.normalized_tags, {
    Name  = "${var.project_name}-${var.env}-${each.key}-role"
    Model = each.key
  })
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  for_each = local.lambda_functions

  role       = aws_iam_role.processor_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  for_each = local.lambda_functions

  role       = aws_iam_role.processor_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "sqs_policy" {
  for_each = local.lambda_functions

  name = "${var.project_name}-${var.env}-${each.key}-sqs-policy"
  role = aws_iam_role.processor_role[each.key].id

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
        Resource = var.sqs_queues[each.key]
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
  role = aws_iam_role.processor_role[each.key].id

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
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Resource = [
          var.aurora_secret_arn,
          var.aurora_kms_key_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecr_policy" {
  for_each = local.lambda_functions

  name = "${var.project_name}-${var.env}-${each.key}-ecr-policy"
  role = aws_iam_role.processor_role[each.key].id

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
      },
      {
        Effect = "Allow"
        Action = "ecr:GetAuthorizationToken"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_policy" {
  for_each = local.lambda_functions

  name = "${var.project_name}-${var.env}-${each.key}-s3-policy"
  role = aws_iam_role.processor_role[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetObjectVersion"
        ]
        Resource = concat(
          var.s3_bucket_arns,
          [for bucket in var.s3_bucket_arns : "${bucket}/*"]
        )
      }
    ]
  })
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  for_each = local.lambda_functions

  event_source_arn = var.sqs_queues[each.key]
  function_name    = aws_lambda_function.processor[each.key].arn
  batch_size       = var.batch_size
  maximum_batching_window_in_seconds = var.batch_window
  enabled          = true
  
  scaling_config {
    maximum_concurrency = var.max_concurrency
  }

  function_response_types = ["ReportBatchItemFailures"]
}

resource "aws_iam_role_policy" "rekognition_policy" {
  for_each = local.lambda_functions

  name = "${var.project_name}-${var.env}-${each.key}-rekognition-policy"
  role = aws_iam_role.processor_role[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rekognition:DetectFaces",
          "rekognition:DetectLabels",
          "rekognition:DetectModerationLabels",
          "rekognition:CompareFaces"
        ]
        Resource = "*"
      }
    ]
  })
}
