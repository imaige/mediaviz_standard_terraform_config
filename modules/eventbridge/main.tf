# eventbridge/main.tf

locals {
  processors = {
    lambda-module1 = "LambdaModule1Processing"
    lambda-module2 = "LambdaModule2Processing"
    lambda-module3 = "LambdaModule3Processing"
    eks-module1    = "EKSModule1Processing"
    eks-module2    = "EKSModule2Processing"
    eks-module3    = "EKSModule3Processing"
  }
}

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

# Processing Rules for all modules
resource "aws_cloudwatch_event_rule" "processing_rules" {
  for_each = local.processors

  name        = "${var.project_name}-${var.env}-${each.key}-processing"
  description = "Trigger ${each.key} processing via SQS"

  event_pattern = jsonencode({
    source      = ["custom.imageUpload"]
    detail-type = [each.value]
    detail = {
      version        = ["1.0"]
      processingType = [each.key]
    }
  })

  tags = merge(var.tags, {
    Environment = var.env
    Module      = each.key
    Type        = can(regex("^lambda-", each.key)) ? "lambda" : "eks"
    Terraform   = "true"
  })
}

# SQS Targets for each module
resource "aws_cloudwatch_event_target" "processor_targets" {
  for_each = local.processors

  rule      = aws_cloudwatch_event_rule.processing_rules[each.key].name
  target_id = "${each.key}ProcessingQueue"
  arn       = var.sqs_queues[each.key]

  # Transform the input to add module-specific information
  input_transformer {
    input_paths = {
      client_id = "$.detail.client_id"
      file_id   = "$.detail.file_id"
      timestamp = "$.time"
      bucket    = "$.detail.bucket"
      key       = "$.detail.key"
    }
    input_template = <<EOF
{
  "client_id": "<client_id>",
  "file_id": "<file_id>",
  "bucket": "<bucket>",
  "key": "<key>",
  "module": "${each.key}",
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

  # Transform the input to add module-specific information
  input_transformer {
    input_paths = {
      client_id = "$.detail.client_id"
      file_id   = "$.detail.file_id"
      timestamp = "$.time"
      bucket    = "$.detail.bucket"
      key       = "$.detail.key"
    }
    input_template = <<EOF
{
  "client_id": "<client_id>",
  "file_id": "<file_id>",
  "bucket": "<bucket>",
  "key": "<key>",
  "module": "${each.key}",
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