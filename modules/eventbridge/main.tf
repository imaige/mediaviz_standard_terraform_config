# eventbridge/main.tf

locals {
  processors = {
    "l-blur-model"                 = "blur_model_processing"
    "l-colors-model"               = "colors_model_processing"
    "l-image-comparison-model"     = "image_comparison_model_processing"
    "l-facial-recognition-model"   = "face_recognition_model_processing"
    "l-feature-extraction-model"   = "feature_extract_model_processing"
    "eks-img-classification-model" = "img_classification_model_processing"
  }
}

# Image Upload Rule
resource "aws_cloudwatch_event_rule" "image_upload" {
  name        = "${var.project_name}-${var.env}-image-upload"
  description = "Capture image upload events with photo_id and company_id"

  event_pattern = jsonencode({
    source      = ["custom.imageUpload"]
    detail-type = ["ImageUploaded"]
    detail = {
      version = ["1.0"]
    }
  })

  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

# Processing Rules for all models
resource "aws_cloudwatch_event_rule" "processing_rules" {
  for_each = local.processors

  name        = "${var.project_name}-${var.env}-${each.key}-processing"
  description = "Trigger ${each.key} processing via SQS"

  event_pattern = jsonencode({
    source      = ["custom.imageUpload"] // does this need update?
    detail-type = [each.value]
    detail = {
      version        = ["1.0"]
      processingType = [each.key]
    }
  })

  tags = merge(var.tags, {
    Environment = var.env
    Model       = each.key
    Type        = can(regex("^lambda-", each.key)) ? "lambda" : "eks"
    Terraform   = "true"
  })
}

# SQS Targets for each model
resource "aws_cloudwatch_event_target" "processor_targets" {
  for_each = local.processors

  rule      = aws_cloudwatch_event_rule.processing_rules[each.key].name
  target_id = "${each.key}ProcessingQueue"
  arn       = var.sqs_queues[each.key]

  # Transform the input to add model-specific information
  input_transformer {
    input_paths = {
      photo_id      = "$.detail.photo_id"
      timestamp     = "$.time"
      bucket        = "$.detail.bucket"
      photo_s3_link = "$.detail.photo_s3_link"
    }

    input_template = <<EOF
{
  "photo_id": "<photo_id>",
  "bucket": "<bucket>",
  "photo_s3_link": "<photo_s3_link>",
  "model": "${each.key}",
  "processor_type": "${can(regex("^lambda-", each.key)) ? "lambda" : "eks"}",
  "timestamp": "<timestamp>"
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

# Fan-out target from main upload event
resource "aws_cloudwatch_event_target" "fanout_targets" {
  for_each = local.processors

  rule      = aws_cloudwatch_event_rule.image_upload.name
  target_id = "${each.key}InitialTarget"
  arn       = var.sqs_queues[each.key]

  # Transform the input to add model-specific information
  input_transformer {
    input_paths = {
      photo_id      = "$.detail.photo_id"
      timestamp     = "$.time"
      bucket        = "$.detail.bucket"
      photo_s3_link = "$.detail.photo_s3_link"
    }

    input_template = <<EOF
{
  "photo_id": "<photo_id>",
  "bucket": "<bucket>",
  "photo_s3_link": "<photo_s3_link>",
  "model": "${each.key}",
  "processor_type": "${can(regex("^lambda-", each.key)) ? "lambda" : "eks"}",
  "timestamp": "<timestamp>"
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
