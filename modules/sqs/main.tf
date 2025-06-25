# sqs/main.tf

locals {
  lambda_models = ["lambda-blur-model", "lambda-colors-model", "lambda-image-comparison-model", "lambda-facial-recognition-model"]
  eks_models    = ["eks-image-classification-model", "eks-feature-extraction-model", "eks-evidence-model", "eks-similarity-model", "eks-personhood-model", "eks-similarity-set-sorting-service", "eks-external-api"]
  all_models    = concat(local.lambda_models, local.eks_models)

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
  delay_seconds              = var.delay_seconds
  max_message_size           = var.max_message_size
  receive_wait_time_seconds  = 20

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

# Processing queues for all models
resource "aws_sqs_queue" "model_queues" {
  for_each = toset(local.all_models)

  name = "${var.project_name}-${var.env}-${each.key}-queue"

  visibility_timeout_seconds = try(var.model_specific_config[each.key].visibility_timeout, var.visibility_timeout)
  message_retention_seconds  = var.retention_period
  delay_seconds              = try(var.model_specific_config[each.key].delay_seconds, var.delay_seconds)
  max_message_size           = var.max_message_size
  receive_wait_time_seconds  = 20

  sqs_managed_sse_enabled = true

  redrive_policy = var.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.model_dlqs[each.key].arn
    maxReceiveCount = coalesce(
      try(var.model_specific_config[each.key].max_receive_count, null),
      var.max_receive_count,
      3
    )
  }) : null

  tags = merge(local.normalized_tags, {
    environment = var.env
    model       = each.key
    type        = can(regex("^lambda-", each.key)) ? "lambda" : "eks"
    terraform   = "true"
  })
}

# Module DLQs
resource "aws_sqs_queue" "model_dlqs" {
  for_each = var.enable_dlq ? toset(local.all_models) : []

  name = "${var.project_name}-${var.env}-${each.key}-dlq"

  message_retention_seconds = var.dlq_retention_period
  receive_wait_time_seconds = 20

  sqs_managed_sse_enabled = true

  tags = merge(local.normalized_tags, {
    environment = var.env
    model       = each.key
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
        Sid    = "AllowSourceServices"
        Effect = "Allow"
        Principal = {
          Service = ["events.amazonaws.com", "lambda.amazonaws.com"]
        }
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.image_processing.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" : var.source_arns
          }
        }
      },
      {
        Sid       = "DenyNonSSLAccess"
        Effect    = "Deny"
        Principal = "*"
        Action = [
          "sqs:*"
        ]
        Resource = aws_sqs_queue.image_processing.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" : "false"
          }
        }
      }
    ]
  })
}

# Module queue policies
resource "aws_sqs_queue_policy" "model_queues" {
  for_each = toset(local.all_models)

  queue_url = aws_sqs_queue.model_queues[each.key].url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridge"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.model_queues[each.key].arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" : [
              "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/${var.project_name}-${var.env}-image-upload",
              "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/${replace(each.key, "lambda-", "l-")}"
            ]
          }
        }
      },
      {
        Sid    = "AllowProcessorAccess"
        Effect = "Allow"
        Principal = {
          AWS = can(regex("^l-", each.key)) ? var.lambda_role_arns : [var.eks_role_arn]
        }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = aws_sqs_queue.model_queues[each.key].arn
      }
    ]
  })
}

# Add these data sources at the top of your file
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}