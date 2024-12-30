# sqs/main.tf

resource "aws_sqs_queue" "image_processing" {
  name = "${var.project_name}-${var.env}-image-processing"
  
  visibility_timeout_seconds = var.visibility_timeout
  message_retention_seconds  = var.retention_period
  delay_seconds             = var.delay_seconds
  max_message_size          = var.max_message_size
  
  # Enable encryption
  sqs_managed_sse_enabled = true
  
  # Add redrive policy
  redrive_policy = var.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  }) : null

  # Enable server-side encryption
  # kms_master_key_id = var.kms_key_id

  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

# Dead Letter Queue (DLQ)
resource "aws_sqs_queue" "dlq" {
  count = var.enable_dlq ? 1 : 0
  
  name = "${var.project_name}-${var.env}-image-processing-dlq"
  
  message_retention_seconds = var.dlq_retention_period
  
  # Enable encryption
  sqs_managed_sse_enabled = true
  # kms_master_key_id       = var.kms_key_id
  
  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

# SQS Queue Policy
resource "aws_sqs_queue_policy" "image_processing" {
  queue_url = aws_sqs_queue.image_processing.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.image_processing.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn": var.eventbridge_rule_arn
          }
        }
      }
    ]
  })
}