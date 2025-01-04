# lambda_processors/main.tf

locals {
  lambda_functions = ["module1", "module2", "module3"]
}

data "archive_file" "processor_package" {
  for_each = toset(local.lambda_functions)

  type        = "zip"
  source_dir  = "${path.module}/functions/${each.key}"
  output_path = "${path.module}/dist/${each.key}.zip"
}

resource "aws_lambda_function" "processor" {
  for_each = toset(local.lambda_functions)

  filename         = data.archive_file.processor_package[each.key].output_path
  function_name    = "${var.project_name}-${var.env}-${each.key}-processor"
  role            = aws_iam_role.processor_role[each.key].arn
  handler         = "handler.handle_processing"
  runtime         = var.lambda_runtime
  memory_size     = var.memory_size
  timeout         = var.timeout

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

  tags = merge(var.tags, {
    Environment = var.env
    Module      = each.key
    Terraform   = "true"
  })
}

resource "aws_security_group" "processor_sg" {
  for_each = toset(local.lambda_functions)

  name        = "${var.project_name}-${var.env}-${each.key}-processor-sg"
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

resource "aws_iam_role" "processor_role" {
  for_each = toset(local.lambda_functions)

  name = "${var.project_name}-${var.env}-${each.key}-processor-role"

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

  tags = merge(var.tags, {
    Environment = var.env
    Module      = each.key
    Terraform   = "true"
  })
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  for_each = toset(local.lambda_functions)

  role       = aws_iam_role.processor_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  for_each = toset(local.lambda_functions)

  role       = aws_iam_role.processor_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# SQS processing policy
resource "aws_iam_role_policy" "sqs_policy" {
  for_each = toset(local.lambda_functions)

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
        Resource = var.sqs_queue_arn
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

# Aurora access policy
resource "aws_iam_role_policy" "aurora_policy" {
  for_each = toset(local.lambda_functions)

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
  
  scaling_config {
    maximum_concurrency = 2
  }

  function_response_types = ["ReportBatchItemFailures"]
}