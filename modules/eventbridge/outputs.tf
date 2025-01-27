# eventbridge/outputs.tf

# Temporarily commented out while rules are removed
output "processing_rule_arns" {
  description = "ARNs of the EventBridge processing rules"
  value       = { for k, v in aws_cloudwatch_event_rule.processing_rules : k => v.arn }
}

output "processing_rule_names" {
  description = "Names of the EventBridge processing rules"
  value       = { for k, v in aws_cloudwatch_event_rule.processing_rules : k => v.name }
}

# Keeping this output since the log group is still active
output "event_bus_log_group" {
  description = "Name of the CloudWatch Log Group for EventBridge events"
  value       = aws_cloudwatch_log_group.eventbridge_logs.name
}

# Temporary empty list output to satisfy any dependencies
output "event_bus_rule_arns" {
  description = "Temporary empty list while rules are being recreated"
  value       = []
}