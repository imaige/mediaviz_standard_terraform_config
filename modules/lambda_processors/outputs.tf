# Outputs for reference in other modules
output "function_arns" {
  description = "ARNs of the Lambda functions"
  value = {
    for k, v in aws_lambda_function.processor : k => v.arn
  }
}

output "function_names" {
  description = "Names of the Lambda functions"
  value = {
    for k, v in aws_lambda_function.processor : k => v.function_name
  }
}

output "role_arns" {
  description = "ARNs of the IAM roles"
  value = {
    for k, v in aws_iam_role.processor_role : k => v.arn
  }
}

output "all_role_arns" {
  description = "List of all IAM role ARNs"
  value       = values(aws_iam_role.processor_role)[*].arn
}

output "all_security_group_ids" {
  description = "List of all security group IDs"
  value       = values(aws_security_group.processor_sg)[*].id
}