# sqs/main.tf

# Main queue
resource "aws_sqs_queue" "image_processing" {
  name = "${var.project_name}-${var.env}-image-processing"
  
  # Message settings
  visibility_timeout_seconds = var.visibility_timeout
  message_retention_seconds  = var.retention_period  # 4 days default
  delay_seconds             = var.delay_seconds
  max_message_size          = var.max_message_size  # in bytes
  receive_wait_time_seconds = 20  # Enable long polling
  
  # Encryption
  sqs_managed_sse_enabled = true
  # kms_master_key_id = var.kms_key_id  # Uncomment if using custom KMS key
  
  # DLQ configuration
  redrive_policy = var.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  }) : null

  # Prevent deletion in production
  fifo_queue           = false  # Standard queue
  deduplication_scope  = null   # Only for FIFO queues
  fifo_throughput_limit = null  # Only for FIFO queues

  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

# Dead Letter Queue (DLQ)
resource "aws_sqs_queue" "dlq" {
  count = var.enable_dlq ? 1 : 0
  
  name = "${var.project_name}-${var.env}-image-processing-dlq"
  
  message_retention_seconds = var.dlq_retention_period  # Longer retention for failed messages
  receive_wait_time_seconds = 20  # Enable long polling
  
  # Encryption
  sqs_managed_sse_enabled = true
  # kms_master_key_id     = var.kms_key_id  # Uncomment if using custom KMS key
  
  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

# Queue policy with comprehensive permissions

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
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.image_processing.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn": var.source_arns
          }
        }
      },
      {
        Sid = "LambdaProcessingAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.lambda_role_arns
        }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = aws_sqs_queue.image_processing.arn
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

# DLQ policy
resource "aws_sqs_queue_policy" "dlq" {
  count = var.enable_dlq ? 1 : 0
  
  queue_url = aws_sqs_queue.dlq[0].url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowMainQueueDLQ"
        Effect = "Allow"
        Principal = "*"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.dlq[0].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn": aws_sqs_queue.image_processing.arn
          }
        }
      },
      {
        Sid = "LambdaDLQAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.lambda_role_arns
        }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = aws_sqs_queue.dlq[0].arn
      },
      {
        Sid = "DenyNonSSLAccess"
        Effect = "Deny"
        Principal = "*"
        Action = "*"
        Resource = aws_sqs_queue.dlq[0].arn
        Condition = {
          Bool = {
            "aws:SecureTransport": "false"
          }
        }
      }
    ]
  })
}