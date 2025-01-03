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

resource "aws_cloudwatch_event_rule" "file_upload_rule" {
  name = "FileUploadRule"

  event_pattern = <<EOF
{
  "source": ["custom.myapp"],
  "detail-type": ["FileUploaded"],
  "detail": {
    "bucketName": ["my-s3-bucket"]
  }
}
EOF
}

# Targets for SQS Queues (EKS Models)
resource "aws_cloudwatch_event_target" "eks_model1_target" {
  rule      = aws_cloudwatch_event_rule.file_upload_rule.name
  target_id = "trigger-eks-model1"
  arn       = aws_sqs_queue.eks_model1_queue.arn
}

resource "aws_cloudwatch_event_target" "eks_model2_target" {
  rule      = aws_cloudwatch_event_rule.file_upload_rule.name
  target_id = "trigger-eks-model2"
  arn       = aws_sqs_queue.eks_model2_queue.arn
}

resource "aws_cloudwatch_event_target" "eks_model3_target" {
  rule      = aws_cloudwatch_event_rule.file_upload_rule.name
  target_id = "trigger-eks-model3"
  arn       = aws_sqs_queue.eks_model3_queue.arn
}

# Targets for SQS Queues (Lambda Models)
resource "aws_cloudwatch_event_target" "lambda_model1_target" {
  rule      = aws_cloudwatch_event_rule.file_upload_rule.name
  target_id = "trigger-lambda-model1"
  arn       = aws_sqs_queue.lambda_model1_queue.arn
}

resource "aws_cloudwatch_event_target" "lambda_model2_target" {
  rule      = aws_cloudwatch_event_rule.file_upload_rule.name
  target_id = "trigger-lambda-model2"
  arn       = aws_sqs_queue.lambda_model2_queue.arn
}

resource "aws_cloudwatch_event_target" "lambda_model3_target" {
  rule      = aws_cloudwatch_event_rule.file_upload_rule.name
  target_id = "trigger-lambda-model3"
  arn       = aws_sqs_queue.lambda_model3_queue.arn
}
