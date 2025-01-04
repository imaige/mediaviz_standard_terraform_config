# eventbridge/variables.tf

variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "env" {
  type        = string
  description = "Environment name"
}

variable "sqs_queue_arn" {
  type        = string
  description = "ARN of the SQS queue to send events to"
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