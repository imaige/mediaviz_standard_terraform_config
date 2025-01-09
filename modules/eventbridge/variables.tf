# eventbridge/variables.tf

variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "env" {
  type        = string
  description = "Environment name"
}

variable "sqs_queues" {
  type        = map(string)
  description = "Map of module names to their SQS queue ARNs"
}

variable "dlq_arn" {
  type        = string
  description = "ARN of the Dead Letter Queue"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags for resources"
  default     = {}
}