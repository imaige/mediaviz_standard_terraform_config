# sqs/outputs.tf

# Main queue outputs
output "queue_arn" {
  description = "ARN of the main processing queue"
  value       = aws_sqs_queue.image_processing.arn
}

output "queue_url" {
  description = "URL of the main processing queue"
  value       = aws_sqs_queue.image_processing.url
}

# Module queues outputs
output "module_queues" {
  description = "Map of all module queue details"
  value = {
    for k, v in aws_sqs_queue.module_queues : k => {
      arn         = v.arn
      url         = v.url
      name        = v.name
      queue_type  = can(regex("^lambda-", k)) ? "lambda" : "eks"
    }
  }
}

# Lambda-specific queue outputs
output "lambda_queue_arns" {
  description = "Map of Lambda module names to their queue ARNs"
  value = {
    for k, v in aws_sqs_queue.module_queues : k => v.arn
    if can(regex("^lambda-", k))
  }
}

output "lambda_queue_urls" {
  description = "Map of Lambda module names to their queue URLs"
  value = {
    for k, v in aws_sqs_queue.module_queues : k => v.url
    if can(regex("^lambda-", k))
  }
}

# EKS-specific queue outputs
output "eks_queue_arns" {
  description = "Map of EKS module names to their queue ARNs"
  value = {
    for k, v in aws_sqs_queue.module_queues : k => v.arn
    if can(regex("^eks-", k))
  }
}

output "eks_queue_urls" {
  description = "Map of EKS module names to their queue URLs"
  value = {
    for k, v in aws_sqs_queue.module_queues : k => v.url
    if can(regex("^eks-", k))
  }
}

# DLQ outputs
output "dlq_arn" {
  description = "ARN of the main DLQ"
  value       = var.enable_dlq ? aws_sqs_queue.image_processing_dlq[0].arn : null
}

output "dlq_url" {
  description = "URL of the main DLQ"
  value       = var.enable_dlq ? aws_sqs_queue.image_processing_dlq[0].url : null
}

output "module_dlqs" {
  description = "Map of module DLQ details"
  value = var.enable_dlq ? {
    for k, v in aws_sqs_queue.module_dlqs : k => {
      arn = v.arn
      url = v.url
      name = v.name
    }
  } : {}
}

# Aggregated outputs for easy reference
output "all_queue_arns" {
  description = "List of all queue ARNs including main queue and module queues"
  value = concat(
    [aws_sqs_queue.image_processing.arn],
    [for q in aws_sqs_queue.module_queues : q.arn]
  )
}

output "all_dlq_arns" {
  description = "List of all DLQ ARNs if enabled"
  value = var.enable_dlq ? concat(
    [aws_sqs_queue.image_processing_dlq[0].arn],
    [for q in aws_sqs_queue.module_dlqs : q.arn]
  ) : []
}

# For CloudWatch and metrics reference
output "queue_names" {
  description = "Map of all queue names for monitoring"
  value = merge(
    {
      main = aws_sqs_queue.image_processing.name
    },
    {
      for k, v in aws_sqs_queue.module_queues : k => v.name
    }
  )
}