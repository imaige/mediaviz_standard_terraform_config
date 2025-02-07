# eventbridge/main.tf

locals {
  processors = {
    "l-blur-model"                 = "blur_model_processing"
    "l-colors-model"               = "colors_model_processing"
    "l-image-comparison-model"     = "image_comparison_model_processing"
    "l-facial-recognition-model"   = "face_recognition_model_processing"
    "eks-image-classification-model" = "image_classification_model_processing"
    "eks-feature-extraction-model" = "feature_extraction_model_processing"
  }
}

# Image Upload Rule
resource "aws_cloudwatch_event_rule" "image_upload" {
  name        = "${var.project_name}-${var.env}-image-upload"
  description = "Capture image upload events"

  event_pattern = jsonencode({
    source      = ["custom.imageUpload"]
    detail-type = ["ImageUploaded"]
  })
}

# Processing Rules for all models
resource "aws_cloudwatch_event_rule" "processing_rules" {
  for_each = local.processors

  name        = each.key
  description = "Trigger ${each.key} processing via SQS"

  event_pattern = jsonencode({
    source      = ["custom.imageUpload"]
    detail-type = [each.value]
  })

  tags = merge(var.tags, {
    Environment = var.env
    Model       = each.key
    Type        = can(regex("^l-", each.key)) ? "lambda" : "eks"
  })
}

# SQS Targets for each model
resource "aws_cloudwatch_event_target" "processor_targets" {
  for_each = local.processors

  rule      = aws_cloudwatch_event_rule.processing_rules[each.key].name
  target_id = "${each.key}ProcessingQueue"
  arn       = var.sqs_queues[each.key]

  # Transform the input to ensure proper formatting
  input_transformer {
    input_paths = {
      "source"      = "$.source"
      "detail-type" = "$.detail-type"
      "detail"      = "$.detail"
    }
    input_template = <<EOF
{
  "source": <source>,
  "detail-type": <detail-type>,
  "detail": <detail>
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
  })
}

# Debug target (optional - remove if not needed)
resource "aws_cloudwatch_event_target" "debug_target" {
  rule      = "l-image-comparison-model"
  target_id = "DebugTarget"
  arn       = aws_cloudwatch_log_group.eventbridge_logs.arn

  input_transformer {
    input_paths = {
      source      = "$.source"
      detailtype  = "$.detail-type"
      detail      = "$.detail"
    }
    input_template = <<EOF
{
  "source": <source>,
  "detail-type": <detailtype>,
  "detail": <detail>,
  "debug": "Matching event received"
}
EOF
  }
}