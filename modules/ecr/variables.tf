# modules/ecr/variables.tf

variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "env" {
  type        = string
  description = "Environment (dev, staging, prod)"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of KMS key for ECR encryption"
}

variable "cross_account_arns" {
  type        = list(string)
  description = "List of ARNs that should have pull access to the repositories"
  default     = []
}