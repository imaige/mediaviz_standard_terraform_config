data "archive_file" "lambda_package" {
  type        = "zip"
  source_dir  = "${path.module}/functions/image_upload"
  output_path = "${path.module}/dist/image_upload.zip"
}

resource "aws_lambda_function" "image_upload" {
  filename         = data.archive_file.lambda_package.output_path
  function_name    = "${var.project_name}-${var.env}-image-upload"
  role            = aws_iam_role.lambda_role.arn
  handler         = "handler.handle_upload"
  runtime         = var.lambda_runtime
  memory_size     = var.memory_size
  timeout         = var.timeout

  environment {
    variables = {
      BUCKET_NAME = var.s3_bucket_name
    }
  }

  tags = var.tags
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-${var.env}-image-upload-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for S3 access
resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "${var.project_name}-${var.env}-image-upload-s3-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${var.s3_bucket_arn}/*"
      }
    ]
  })
}

# CloudWatch Logs policy
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_eventbridge_policy" {
  name = "${var.project_name}-${var.env}-image-upload-eventbridge-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "processor_package" {
  type        = "zip"
  source_dir  = "${path.module}/functions/image_processor"
  output_path = "${path.module}/dist/image_processor.zip"
}

resource "aws_lambda_function" "image_processor" {
  filename         = data.archive_file.processor_package.output_path
  function_name    = "${var.project_name}-${var.env}-image-processor"
  role            = aws_iam_role.processor_role.arn
  handler         = "handler.handle_processing"
  runtime         = var.lambda_runtime
  memory_size     = var.memory_size
  timeout         = var.timeout

  environment {
    variables = {
      OUTPUT_BUCKET = var.output_bucket_name
      SOURCE_BUCKET = var.s3_bucket_name
    }
  }

  tags = var.tags
}

# IAM role for Processor Lambda
resource "aws_iam_role" "processor_role" {
  name = "${var.project_name}-${var.env}-image-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for S3 access (both read and write)
resource "aws_iam_role_policy" "processor_s3_policy" {
  name = "${var.project_name}-${var.env}-image-processor-s3-policy"
  role = aws_iam_role.processor_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "${var.s3_bucket_arn}/*",
          "${var.output_bucket_arn}/*"
        ]
      }
    ]
  })
}

# CloudWatch Logs policy
resource "aws_iam_role_policy_attachment" "processor_logs" {
  role       = aws_iam_role.processor_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# SQS policy
resource "aws_iam_role_policy" "processor_sqs_policy" {
  name = "${var.project_name}-${var.env}-image-processor-sqs-policy"
  role = aws_iam_role.processor_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

# SQS trigger for Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.sqs_queue_arn
  function_name    = aws_lambda_function.image_processor.arn
  batch_size       = 1
}