variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env" {
  description = "Environment (dev, qa, prod, shared)"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of KMS key for ECR encryption"
  type        = string
}

variable "cross_account_arns" {
  description = "List of cross-account ARNs that can access these repositories"
  type        = list(string)
  default     = []
}

# Add this variable to override the local repositories list in main.tf
variable "ecr_repositories" {
  description = "List of ECR repositories to create"
  type        = list(string)
  default     = [] # Empty default allows the module to use its internal local.repositories if not specified
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}