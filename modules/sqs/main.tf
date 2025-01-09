# sqs/main.tf

locals {
  lambda_modules = ["lambda-module1", "lambda-module2", "lambda-module3"]
  eks_modules    = ["eks-module1", "eks-module2", "eks-module3"]
  all_modules    = concat(local.lambda_modules, local.eks_modules)
  
  # Normalize tags to lowercase to prevent case-sensitivity issues
  normalized_tags = {
    for key, value in var.tags :
    lower(key) => value
  }
}

# Main queue
resource "aws_sqs_queue" "image_processing" {
  name = "${var.project_name}-${var.env}-image-processing"
  
  visibility_timeout_seconds = var.visibility_timeout
  message_retention_seconds  = var.retention_period
  delay_seconds             = var.delay_seconds
  max_message_size          = var.max_message_size
  receive_wait_time_seconds = 20
  
  sqs_managed_sse_enabled = true
  
  redrive_policy = var.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.image_processing_dlq[0].arn
    maxReceiveCount     = coalesce(var.max_receive_count, 3)
  }) : null

  tags = merge(local.normalized_tags, {
    environment = var.env
    terraform   = "true"
  })
}

# Main DLQ
resource "aws_sqs_queue" "image_processing_dlq" {
  count = var.enable_dlq ? 1 : 0
  
  name = "${var.project_name}-${var.env}-image-processing-dlq"
  
  message_retention_seconds = var.dlq_retention_period
  receive_wait_time_seconds = 20
  
  sqs_managed_sse_enabled = true
  
  tags = merge(local.normalized_tags, {
    environment = var.env
    type        = "dlq"
    terraform   = "true"
  })
}

# Processing queues for all modules
resource "aws_sqs_queue" "module_queues" {
  for_each = toset(local.all_modules)

  name = "${var.project_name}-${var.env}-${each.key}-queue"
  
  visibility_timeout_seconds = try(var.module_specific_config[each.key].visibility_timeout, var.visibility_timeout)
  message_retention_seconds  = var.retention_period
  delay_seconds             = try(var.module_specific_config[each.key].delay_seconds, var.delay_seconds)
  max_message_size          = var.max_message_size
  receive_wait_time_seconds = 20
  
  sqs_managed_sse_enabled = true
  
  redrive_policy = var.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.module_dlqs[each.key].arn
    maxReceiveCount     = coalesce(
      try(var.module_specific_config[each.key].max_receive_count, null),
      var.max_receive_count,
      3
    )
  }) : null

  tags = merge(local.normalized_tags, {
    environment = var.env
    module      = each.key
    type        = can(regex("^lambda-", each.key)) ? "lambda" : "eks"
    terraform   = "true"
  })
}

# Module DLQs
resource "aws_sqs_queue" "module_dlqs" {
  for_each = var.enable_dlq ? toset(local.all_modules) : []
  
  name = "${var.project_name}-${var.env}-${each.key}-dlq"
  
  message_retention_seconds = var.dlq_retention_period
  receive_wait_time_seconds = 20
  
  sqs_managed_sse_enabled = true
  
  tags = merge(local.normalized_tags, {
    environment = var.env
    module      = each.key
    type        = "${can(regex("^lambda-", each.key)) ? "lambda" : "eks"}-dlq"
    terraform   = "true"
  })
}

# Queue Policies
resource "aws_sqs_queue_policy" "image_processing" {
  queue_url = aws_sqs_queue.image_processing.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowSourceServices"
        Effect = "Allow"
        Principal = {
          Service = ["events.amazonaws.com", "lambda.amazonaws.com"]
        }
        Action = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.image_processing.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn": var.source_arns
          }
        }
      },
      {
        Sid = "DenyNonSSLAccess"
        Effect = "Deny"
        Principal = "*"
        Action = "*"
        Resource = aws_sqs_queue.image_processing.arn
        Condition = {
          Bool = {
            "aws:SecureTransport": "false"
          }
        }
      }
    ]
  })
}

# Module queue policies
resource "aws_sqs_queue_policy" "module_queues" {
  for_each = toset(local.all_modules)

  queue_url = aws_sqs_queue.module_queues[each.key].url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowEventBridge"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.module_queues[each.key].arn
        Condition = {
          ArnLike = {
            "aws:SourceArn": var.source_arns
          }
        }
      },
      {
        Sid = "AllowProcessorAccess"
        Effect = "Allow"
        Principal = {
          AWS = can(regex("^lambda-", each.key)) ? var.lambda_role_arns : [var.eks_role_arn]
        }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = aws_sqs_queue.module_queues[each.key].arn
      },
      {
        Sid = "DenyNonSSLAccess"
        Effect = "Deny"
        Principal = "*"
        Action = "*"
        Resource = aws_sqs_queue.module_queues[each.key].arn
        Condition = {
          Bool = {
            "aws:SecureTransport": "false"
          }
        }
      }
    ]
  })
}