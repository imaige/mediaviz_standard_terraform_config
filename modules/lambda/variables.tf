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

variable "output_bucket_name" {
  type = string
}

variable "output_bucket_arn" {
  type = string
}

variable "sqs_queue_arn" {
  type = string
}