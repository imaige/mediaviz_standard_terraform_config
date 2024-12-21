output "queue_id" {
  description = "The ID of the SQS queue"
  value       = aws_sqs_queue.image_processing.id
}

output "queue_arn" {
  description = "The ARN of the SQS queue"
  value       = aws_sqs_queue.image_processing.arn
}

output "queue_url" {
  description = "The URL of the SQS queue"
  value       = aws_sqs_queue.image_processing.url
}

output "dlq_id" {
  description = "The ID of the Dead Letter Queue"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].id : null
}

output "dlq_arn" {
  description = "The ARN of the Dead Letter Queue"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
}

output "dlq_url" {
  description = "The URL of the Dead Letter Queue"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].url : null
}