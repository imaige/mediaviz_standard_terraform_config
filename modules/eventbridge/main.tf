# eventbridge/main.tf

# Image Upload Rule
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

  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

# Module1 Processing Rule
resource "aws_cloudwatch_event_rule" "module1_processing" {
  name        = "${var.project_name}-${var.env}-module1-processing"
  description = "Trigger module1 processing via SQS"

  event_pattern = jsonencode({
    source      = ["custom.imageUpload"]
    detail-type = ["Module1Processing"]
    detail = {
      version        = ["1.0"]
      processingType = ["module1"]
    }
  })

  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

# Module2 Processing Rule
resource "aws_cloudwatch_event_rule" "module2_processing" {
  name        = "${var.project_name}-${var.env}-module2-processing"
  description = "Trigger module2 processing via SQS"

  event_pattern = jsonencode({
    source      = ["custom.imageUpload"]
    detail-type = ["Module2Processing"]
    detail = {
      version        = ["1.0"]
      processingType = ["module2"]
    }
  })

  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

# Module3 Processing Rule
resource "aws_cloudwatch_event_rule" "module3_processing" {
  name        = "${var.project_name}-${var.env}-module3-processing"
  description = "Trigger module3 processing via SQS"

  event_pattern = jsonencode({
    source      = ["custom.imageUpload"]
    detail-type = ["Module3Processing"]
    detail = {
      version        = ["1.0"]
      processingType = ["module3"]
    }
  })

  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

# SQS Targets for each rule
resource "aws_cloudwatch_event_target" "sqs_targets" {
  for_each = {
    module1 = aws_cloudwatch_event_rule.module1_processing.name
    module2 = aws_cloudwatch_event_rule.module2_processing.name
    module3 = aws_cloudwatch_event_rule.module3_processing.name
  }

  rule      = each.value
  target_id = "${each.key}ProcessingQueue"
  arn       = var.sqs_queue_arn

  # Transform the input to add module-specific information
  input_transformer {
    input_paths = {
      client_id = "$.detail.client_id",
      file_id   = "$.detail.file_id",
      timestamp = "$.time"
    }
    input_template = <<EOF
{
  "client_id": "<client_id>",
  "file_id": "<file_id>",
  "module": "${each.key}",
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

# Original image upload target
resource "aws_cloudwatch_event_target" "sqs" {
  rule      = aws_cloudwatch_event_rule.image_upload.name
  target_id = "ProcessImageQueue"
  arn       = var.sqs_queue_arn

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
