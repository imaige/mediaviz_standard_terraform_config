# lambda_upload/variables.tf

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

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "kms_key_id" {
  description = "ID of the KMS key for encryption"
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

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "aurora_cluster_arn" {
  description = "ARN of the Aurora Serverless cluster"
  type        = string
}

variable "aurora_secret_arn" {
  description = "ARN of the Aurora Serverless secret in Secrets Manager"
  type        = string
}

variable "aurora_database_name" {
  description = "Name of the Aurora database"
  type        = string
}

variable "aurora_kms_key_arn" {
  description = "ARN of the KMS key used for Aurora encryption"
  type        = string
}
