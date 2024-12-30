output "api_endpoint" {
  description = "API Gateway invocation URL"
  value       = "${aws_api_gateway_stage.api_stage.invoke_url}/upload"
}

output "execution_arn" {
  description = "API Gateway execution ARN"
  value       = aws_api_gateway_rest_api.image_upload.execution_arn
}
output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_app_client_id" {
  value = aws_cognito_user_pool_client.client.id
}