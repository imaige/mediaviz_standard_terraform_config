# API Gateway
resource "aws_api_gateway_rest_api" "image_upload" {
  name = "${var.project_name}-${var.env}-upload-api"
}

# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-${var.env}-user-pool"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  auto_verified_attributes = ["email"]
  
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }
}

resource "aws_cognito_user_pool_client" "client" {
  name         = "${var.project_name}-${var.env}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false
  
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]
}

resource "aws_api_gateway_authorizer" "cognito" {
  name          = "cognito-authorizer"
  type          = "COGNITO_USER_POOLS"
  rest_api_id   = aws_api_gateway_rest_api.image_upload.id
  provider_arns = [aws_cognito_user_pool.main.arn]
}

# API Resources and Methods
resource "aws_api_gateway_resource" "upload" {
  rest_api_id = aws_api_gateway_rest_api.image_upload.id
  parent_id   = aws_api_gateway_rest_api.image_upload.root_resource_id
  path_part   = "upload"
}

resource "aws_api_gateway_method" "upload_post" {
  rest_api_id   = aws_api_gateway_rest_api.image_upload.id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_parameters = {
    "method.request.header.Authorization" = true
  }
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.image_upload.id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.upload_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = var.lambda_invoke_arn
}

# CORS Configuration
resource "aws_api_gateway_method" "upload_options" {
  rest_api_id   = aws_api_gateway_rest_api.image_upload.id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.image_upload.id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.upload_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.image_upload.id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.upload_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.image_upload.id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.upload_options.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Deployment and Stage
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.image_upload.id

  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.options_integration
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id  = aws_api_gateway_rest_api.image_upload.id
  stage_name   = var.stage_name
}

# Lambda Permission
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.image_upload.execution_arn}/*/*"
}
resource "aws_cognito_user" "admin" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = "admin@example.com"
  
  attributes = {
    email          = "admin@example.com"
    email_verified = true
  }
}