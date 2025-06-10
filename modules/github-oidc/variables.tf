variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env" {
  description = "Environment (dev, qa, prod, shared)"
  type        = string
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
  default     = "" # If not provided, current account ID will be used
}

variable "account_type" {
  description = "Type of account (shared, workload)"
  type        = string
  validation {
    condition     = contains(["shared", "workload"], var.account_type)
    error_message = "account_type must be either 'shared' or 'workload'."
  }
}

variable "cross_account_roles" {
  description = "List of cross-account role ARNs that GitHub Actions can assume"
  type        = list(string)
  default     = []
}

variable "shared_ecr_arns" {
  description = "List of ECR repository ARNs from shared account that workload account can access"
  type        = list(string)
  default     = []
}

variable "shared_s3_arns" {
  description = "List of S3 bucket ARNs from shared account that workload account can access"
  type        = list(string)
  default     = []
}

variable "kms_key_arns" {
  description = "List of KMS key ARNs that GitHub Actions can use"
  type        = list(string)
  default     = []
}

variable "cluster_name" {
  description = "Name of the EKS cluster (needed for workload accounts)"
  type        = string
  default     = ""
}

variable "enable_cicd_permissions" {
  description = "Whether to enable enhanced permissions for CI/CD workflows"
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}