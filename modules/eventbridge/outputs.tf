# eventbridge/outputs.tf

output "all_rule_arns" {
  description = "List of all EventBridge rule ARNs"
  value = concat(
    [aws_cloudwatch_event_rule.image_upload.arn],
    [aws_cloudwatch_event_rule.module1_processing.arn],
    [aws_cloudwatch_event_rule.module2_processing.arn],
    [aws_cloudwatch_event_rule.module3_processing.arn]
  )
}

output "image_upload_rule_arn" {
  description = "ARN of the image upload EventBridge rule"
  value = aws_cloudwatch_event_rule.image_upload.arn
}

output "processor_rule_arns" {
  description = "Map of processor module names to their rule ARNs"
  value = {
    module1 = aws_cloudwatch_event_rule.module1_processing.arn
    module2 = aws_cloudwatch_event_rule.module2_processing.arn
    module3 = aws_cloudwatch_event_rule.module3_processing.arn
  }
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.eventbridge_logs.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.eventbridge_logs.arn
}