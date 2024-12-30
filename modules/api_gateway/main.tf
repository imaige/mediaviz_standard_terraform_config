# API Gateway
resource "aws_api_gateway_rest_api" "image_upload" {
  name = "${var.project_name}-${var.env}-upload-api"

  # Enable endpoint configuration
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  # Enable Create before destroy
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_wafregional_web_acl_association" "api_waf" {
  resource_arn = aws_api_gateway_stage.api_stage.arn
  web_acl_id   = var.waf_acl_id
}

# Add request validation
resource "aws_api_gateway_request_validator" "validator" {
  name                        = "validator"
  rest_api_id                 = aws_api_gateway_rest_api.image_upload.id
  validate_request_body       = true
  validate_request_parameters = true
}

# Modify the POST method to include validation and authorization
resource "aws_api_gateway_method" "upload_post" {
  rest_api_id          = aws_api_gateway_rest_api.image_upload.id
  resource_id          = aws_api_gateway_resource.upload.id
  http_method          = "POST"
  authorization        = "AWS_IAM" # Changed from NONE to AWS_IAM
  request_validator_id = aws_api_gateway_request_validator.validator.id

  # Add request validation
  request_models = {
    "application/json" = aws_api_gateway_model.request_model.name
  }
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

# Add request model for validation
resource "aws_api_gateway_model" "request_model" {
  rest_api_id  = aws_api_gateway_rest_api.image_upload.id
  name         = "ImageUploadModel"
  description  = "Image upload request validation model"
  content_type = "application/json"

  schema = jsonencode({
    type     = "object"
    required = ["image"]
    properties = {
      image = {
        type = "string"
      }
    }
  })
}

# Modify the stage to include logging and X-Ray tracing
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.image_upload.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_parameters = {
    "method.request.header.Authorization" = true
  }
  
  stage_name    = var.stage_name

  xray_tracing_enabled = true

  # Enable logging
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  # Enable caching
  cache_cluster_enabled = true
  cache_cluster_size    = "0.5" # Smallest available size

  client_certificate_id = aws_api_gateway_client_certificate.api_cert.id
}

# Add client certificate
resource "aws_api_gateway_client_certificate" "api_cert" {
  description = "Client certificate for ${var.project_name}-${var.env}"
}

# Create log group for API Gateway logs
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${var.project_name}-${var.env}-upload-api"
  retention_in_days = 365 # Changed from 30 to 365
  kms_key_id        = var.kms_key_arn
}

# Modify deployment to include create before destroy
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.image_upload.id

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.options_integration,
    aws_api_gateway_method.upload_post,
    aws_api_gateway_method.upload_options
  ]
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.image_upload.id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.upload_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

resource "aws_api_gateway_method" "upload_options" {
  rest_api_id          = aws_api_gateway_rest_api.image_upload.id
  resource_id          = aws_api_gateway_resource.upload.id
  http_method          = "OPTIONS"
  authorization        = "NONE"
  request_validator_id = aws_api_gateway_request_validator.validator.id
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

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.image_upload.id
  stage_name  = aws_api_gateway_stage.api_stage.stage_name
  method_path = "*/*"

  settings {
    logging_level        = "INFO"
    data_trace_enabled   = false
    metrics_enabled      = true
    caching_enabled      = true
    cache_data_encrypted = true
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
