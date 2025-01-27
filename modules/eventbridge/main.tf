# eventbridge/main.tf

locals {
  processors = {
    "l-blur-model"                 = "blur_model_processing"
    "l-colors-model"               = "colors_model_processing"
    "l-image-comparison-model"     = "image_comparison_model_processing"
    "l-facial-recognition-model"   = "face_recognition_model_processing"
    "eks-img-classification-model" = "image_classification_model_processing"
    "eks-feature-extraction-model" = "feature_extraction_model_processing"
  }
}

# Processing Rules for all models
resource "aws_cloudwatch_event_rule" "processing_rules" {
  for_each = local.processors

  name        = each.key  # Using just the model name as the rule name
  description = "Trigger ${each.key} processing via SQS"

  event_pattern = jsonencode({
    source       = ["custom.imageUpload"]
    "detail-type" = [each.value]
  })

  tags = merge(var.tags, {
    Environment = var.env
    Model       = each.key
    Type        = can(regex("^l-", each.key)) ? "lambda" : "eks"
    Terraform   = "true"
  })
}

# SQS Targets for each model
resource "aws_cloudwatch_event_target" "processor_targets" {
  for_each = local.processors

  rule      = aws_cloudwatch_event_rule.processing_rules[each.key].name  # Reference the rule by its resource name
  target_id = "${each.key}ProcessingQueue"
  arn       = var.sqs_queues[each.key]

  # Transform the input to add model-specific information
  input_transformer {
    input_paths = {
      photo_id      = "$.detail.photo_id"
      timestamp     = "$.time"
      bucket        = "$.detail.bucket"
      photo_s3_link = "$.detail.photo_s3_link"
      models        = "$.detail.models"
    }

    input_template = <<EOF
{
  "photo_id": "<photo_id>",
  "bucket": "<bucket>",
  "photo_s3_link": "<photo_s3_link>",
  "model": "${each.key}",
  "processor_type": "${can(regex("^l-", each.key)) ? "lambda" : "eks"}",
  "timestamp": "<timestamp>",
  "models": <models>
}
EOF
  }

  # Add retry policy
  retry_policy {
    maximum_event_age_in_seconds = 86400 # 24 hours
    maximum_retry_attempts       = 3
  }

  # Add dead-letter config
  dead_letter_config {
    arn = var.dlq_arn
  }
}

# CloudWatch Log Group for monitoring
resource "aws_cloudwatch_log_group" "eventbridge_logs" {
  name              = "/aws/events/${var.project_name}-${var.env}-processing"
  retention_in_days = 365

  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}