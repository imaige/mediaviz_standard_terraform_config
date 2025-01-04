# eventbridge/outputs.tf

output "image_upload_rule_arn" {
  description = "ARN of the image upload EventBridge rule"
  value       = aws_cloudwatch_event_rule.image_upload.arn
}

output "image_upload_rule_name" {
  description = "Name of the image upload EventBridge rule"
  value       = aws_cloudwatch_event_rule.image_upload.name
}

output "processing_rules" {
  description = "Map of processing rule details by module"
  value = {
    for k, v in aws_cloudwatch_event_rule.processing_rules : k => {
      arn  = v.arn
      name = v.name
      id   = v.id
    }
  }
}

output "lambda_processing_rules" {
  description = "Map of Lambda processing rule ARNs"
  value = {
    for k, v in aws_cloudwatch_event_rule.processing_rules : k => v.arn
    if can(regex("^lambda-", k))
  }
}

output "eks_processing_rules" {
  description = "Map of EKS processing rule ARNs"
  value = {
    for k, v in aws_cloudwatch_event_rule.processing_rules : k => v.arn
    if can(regex("^eks-", k))
  }
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group for EventBridge"
  value       = aws_cloudwatch_log_group.eventbridge_logs.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Log Group for EventBridge"
  value       = aws_cloudwatch_log_group.eventbridge_logs.arn
}

output "event_bus_rule_arns" {
  description = "List of all EventBridge rule ARNs"
  value = concat(
    [aws_cloudwatch_event_rule.image_upload.arn],
    [for rule in aws_cloudwatch_event_rule.processing_rules : rule.arn]
  )
}

# Optional: Add target details if needed
output "target_ids" {
  description = "Map of target IDs by module"
  value = {
    for k, v in aws_cloudwatch_event_target.processor_targets : k => v.target_id
  }
}