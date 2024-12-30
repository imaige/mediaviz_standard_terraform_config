# eventbridge/main.tf

resource "aws_cloudwatch_event_rule" "image_upload" {
  name        = "${var.project_name}-${var.env}-image-upload"
  description = "Capture image upload events with client_id"

  event_pattern = jsonencode({
    source      = ["custom.imageUpload"]
    detail-type = ["ImageUploaded"]
    detail = {
      version = ["1.0"]
    }
  })

  tags = {
    Environment = var.env
    Terraform   = "true"
  }
}

resource "aws_cloudwatch_event_target" "sqs" {
  rule      = aws_cloudwatch_event_rule.image_upload.name
  target_id = "ProcessImageQueue"
  arn       = var.target_arn

  # Add retry policy
  retry_policy {
    maximum_event_age_in_seconds = 86400  # 24 hours
    maximum_retry_attempts       = 3
  }

  # Add dead-letter config
  dead_letter_config {
    arn = var.aws_sqs_queue_dlq_arn
  }
}

# # Create DLQ for EventBridge
# resource "aws_sqs_queue" "dlq" {
#   name                       = "${var.project_name}-${var.env}-eventbridge-dlq"
#   delay_seconds             = 0
#   max_message_size          = 262144
#   message_retention_seconds = 1209600 # 14 days
  
#   # Enable encryption
#   kms_master_key_id = var.kms_key_id
  
#   tags = {
#     Environment = var.env
#     Terraform   = "true"
#   }
# }

# CloudWatch Log Group for EventBridge
# resource "aws_cloudwatch_log_group" "api_eventbridge_logs" {
#   name              = "/aws/apigateway/${var.project_name}-${var.env}-upload-api"
#   retention_in_days = 365  # Changed from 30 to 365
#   # kms_key_id       = var.kms_key_arn
# }