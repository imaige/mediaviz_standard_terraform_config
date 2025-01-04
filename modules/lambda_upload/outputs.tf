# lambda_upload/outputs.tf

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.image_upload.arn
}

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.image_upload.function_name
}

output "function_url" {
  description = "URL of the Lambda function"
  value       = aws_lambda_function_url.image_upload.function_url
}

output "role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = aws_iam_role.lambda_role.arn
}

output "security_group_id" {
  description = "ID of the Lambda security group"
  value       = aws_security_group.lambda_sg.id
}

output "dlq_arn" {
  description = "ARN of the Lambda DLQ"
  value       = aws_sqs_queue.lambda_dlq.arn
}

output "dlq_url" {
  description = "URL of the Lambda DLQ"
  value       = aws_sqs_queue.lambda_dlq.url
}

output "invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.image_upload.invoke_arn
}