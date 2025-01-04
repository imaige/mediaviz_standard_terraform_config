variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for uploads"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for uploads"
  type        = string
}

variable "memory_size" {
  description = "Memory size for Lambda function"
  type        = number
  default     = 128
}

variable "timeout" {
  description = "Timeout for Lambda function"
  type        = number
  default     = 30
}

variable "lambda_runtime" {
  description = "Runtime for Lambda function"
  type        = string
  default     = "python3.9"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "kms_key_id" {
  description = "ID of the KMS key for encryption"
  type        = string
}

# variable "encrypted_env_var" {
#   description = "Encrypted environment variable value"
#   type        = string
# }

variable "signing_profile_version_arn" {
  description = "ARN of the signing profile version"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for Lambda VPC config"
  type        = list(string)
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "output_bucket_name" {
  type = string
}

variable "output_bucket_arn" {
  type = string
}

variable "sqs_queue_arn" {
  type = string
}

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

variable "sqs_queue_arn" {
  type        = string
  description = "ARN of the SQS queue"
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