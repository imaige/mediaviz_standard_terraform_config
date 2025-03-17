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
  default     = 1024
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

variable "aurora_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt Aurora secrets"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources are deployed"
  type        = string
}

variable "shared_ecr_repository_url" {
  description = "Base URL for ECR repositories in the shared account (if using cross-account)"
  type        = string
  default     = ""
}

variable "reserved_concurrency" {
  description = "Reserved concurrency for Lambda functions (0 means no reservation)"
  type        = number
  default     = 0
}

variable "batch_size" {
  description = "Maximum number of records to process in a batch"
  type        = number
  default     = 1
}

variable "batch_window" {
  description = "Maximum time to wait before processing a batch in seconds"
  type        = number
  default     = 0
}

variable "max_concurrency" {
  description = "Maximum concurrency for Lambda scaling"
  type        = number
  default     = 10
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs that the Lambda functions need access to"
  type        = list(string)
  default     = []
}

variable "additional_environment_variables" {
  description = "Additional environment variables to add to Lambda functions"
  type        = map(string)
  default     = {}
}