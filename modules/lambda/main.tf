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