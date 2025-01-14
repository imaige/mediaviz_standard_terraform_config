# lambda_processors/variables.tf

variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "env" {
  type        = string
  description = "Environment name"
}

variable "lambda_runtime" {
  type        = string
  description = "Lambda runtime"
  default     = "python3.9"
}

variable "memory_size" {
  type        = number
  description = "Lambda memory size"
  default     = 128
}

variable "timeout" {
  type        = number
  description = "Lambda timeout"
  default     = 30
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs"
}

variable "dlq_arn" {
  type        = string
  description = "ARN of the Dead Letter Queue"
}

variable "aurora_cluster_arn" {
  type        = string
  description = "ARN of the Aurora cluster"
}

variable "aurora_secret_arn" {
  type        = string
  description = "ARN of the Aurora secrets in Secrets Manager"
}

variable "aurora_database_name" {
  type        = string
  description = "Name of the Aurora database"
}

variable "aurora_security_group_id" {
  type        = string
  description = "Security group ID of the Aurora cluster"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags for resources"
  default     = {}
}

variable "ecr_repository_url" {
  type        = string
  description = "Base URL for ECR repositories"
}

variable "ecr_repository_arns" {
  type        = list(string)
  description = "List of ECR repository ARNs"
}

variable "sqs_queues" {
  type        = map(string)
  description = "Map of SQS queue ARNs for each lambda function"
}