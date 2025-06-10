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

# Model queues outputs
output "model_queues" {
  description = "Map of all model queue details"
  value = {
    for k, v in aws_sqs_queue.model_queues : k => {
      arn        = v.arn
      url        = v.url
      name       = v.name
      queue_type = can(regex("^lambda-", k)) ? "lambda" : "eks"
    }
  }
}

# Lambda-specific queue outputs
output "lambda_queue_arns" {
  description = "Map of Lambda model names to their queue ARNs"
  value = {
    for k, v in aws_sqs_queue.model_queues : k => v.arn
    if can(regex("^lambda-", k))
  }
}

output "lambda_queue_urls" {
  description = "Map of Lambda model names to their queue URLs"
  value = {
    for k, v in aws_sqs_queue.model_queues : k => v.url
    if can(regex("^lambda-", k))
  }
}

# EKS-specific queue outputs
# In sqs/outputs.tf

output "eks_queue_arns" {
  description = "Map of EKS model queue ARNs"
  value = {
    for model in local.eks_models :
    model => aws_sqs_queue.model_queues[model].arn
  }
}

output "eks_queue_urls" {
  description = "Map of EKS model queue URLs"
  value = {
    for model in local.eks_models :
    model => aws_sqs_queue.model_queues[model].url
  }
}

output "eks_dlq_arns" {
  description = "Map of EKS model dead-letter queue ARNs"
  value = var.enable_dlq ? {
    for model in local.eks_models :
    model => aws_sqs_queue.model_dlqs[model].arn
  } : {}
}

output "eks_dlq_urls" {
  description = "Map of EKS model dead-letter queue URLs"
  value = var.enable_dlq ? {
    for model in local.eks_models :
    model => aws_sqs_queue.model_dlqs[model].url
  } : {}
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

output "model_dlqs" {
  description = "Map of model DLQ details"
  value = var.enable_dlq ? {
    for k, v in aws_sqs_queue.model_dlqs : k => {
      arn  = v.arn
      url  = v.url
      name = v.name
    }
  } : {}
}

# Aggregated outputs for easy reference
output "all_queue_arns" {
  description = "List of all queue ARNs including main queue and model queues"
  value = concat(
    [aws_sqs_queue.image_processing.arn],
    [for q in aws_sqs_queue.model_queues : q.arn]
  )
}

output "all_dlq_arns" {
  description = "List of all DLQ ARNs if enabled"
  value = var.enable_dlq ? concat(
    [aws_sqs_queue.image_processing_dlq[0].arn],
    [for q in aws_sqs_queue.model_dlqs : q.arn]
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
      for k, v in aws_sqs_queue.model_queues : k => v.name
    }
  )
}