# Main API Gateway v2 API
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-${var.env}-upload-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_credentials = false # Changed to false since we're using allow_origins = ["*"]
    allow_headers = [
      "content-type",
      "x-bucket-name",
      "x-file-name",
      "x-models",
      "x-company-id",
      "x-user-id",
      "x-project-table-name",
      "x-client-side-id",
      "x-title",
      "x-description",
      "x-format",
      "x-size",
      "x-source-resolution-x",
      "x-source-resolution-y",
      "x-date-taken",
      "x-latitude",
      "x-longitude",
      "x-photo-index",
      "authorization",
      "x-amz-date",
      "x-api-key",
      "x-amz-security-token"
    ]
    allow_methods = ["POST", "OPTIONS"]
    allow_origins = ["*"]
    expose_headers = [
      "content-type",
      "x-bucket-name",
      "x-company-id",
      "x-date-taken",
      "x-file-name",
      "x-format",
      "x-models",
      "x-project-table-name",
      "x-title",
      "x-user-id",
      "x-photo-index"
    ]
    max_age = 300
  }
}

# Lambda Integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id = aws_apigatewayv2_api.main.id

  integration_type   = "AWS_PROXY"
  integration_uri    = var.lambda_invoke_arn
  integration_method = "POST"

  payload_format_version = "2.0"
  timeout_milliseconds   = 30000

  request_parameters = {
    "overwrite:header.Content-Type" = "multipart/form-data"
  }
}

# Route configuration
resource "aws_apigatewayv2_route" "upload" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Stage configuration
resource "aws_apigatewayv2_stage" "main" {
  api_id = aws_apigatewayv2_api.main.id
  name   = var.stage_name

  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId          = "$context.requestId"
      ip                 = "$context.identity.sourceIp"
      requestTime        = "$context.requestTime"
      httpMethod         = "$context.httpMethod"
      routeKey           = "$context.routeKey"
      status             = "$context.status"
      protocol           = "$context.protocol"
      responseLength     = "$context.responseLength"
      integrationError   = "$context.integrationErrorMessage"
      integrationLatency = "$context.integrationLatency"
    })
  }

  default_route_settings {
    detailed_metrics_enabled = true
    throttling_burst_limit   = 20000
    throttling_rate_limit    = 30000
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${var.project_name}-${var.env}-upload-api"
  retention_in_days = 365
}

# IAM role for API Gateway CloudWatch logging
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.project_name}-${var.env}-api-gateway-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

# Attach CloudWatch logging policy
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*/upload"
}