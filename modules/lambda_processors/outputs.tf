# lambda_processors/outputs.tf

output "function_arns" {
  description = "Map of function names to their ARNs"
  value = {
    for k, v in aws_lambda_function.processor : k => v.arn
  }
}

output "function_names" {
  description = "Map of function names to their function names"
  value = {
    for k, v in aws_lambda_function.processor : k => v.function_name
  }
}

output "role_arns" {
  description = "Map of function names to their IAM role ARNs"
  value = {
    for k, v in aws_iam_role.processor_role_new : k => v.arn
  }
}

output "security_group_ids" {
  description = "Map of function names to their security group IDs"
  value = {
    for k, v in aws_security_group.processor_sg : k => v.id
  }
}

# Flattened list outputs for easier integration
output "all_function_arns" {
  description = "List of all processor function ARNs"
  value = values(aws_lambda_function.processor)[*].arn
}

output "all_role_arns" {
  description = "List of all processor role ARNs"
  value = values(aws_iam_role.processor_role_new)[*].arn
}

output "all_security_group_ids" {
  description = "List of all processor security group IDs"
  value = values(aws_security_group.processor_sg)[*].id
}