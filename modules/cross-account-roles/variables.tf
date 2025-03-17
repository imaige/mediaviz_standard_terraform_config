variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env" {
  description = "Environment (dev, qa, prod)"
  type        = string
  default     = ""
}

variable "account_type" {
  description = "Type of account (shared, workload)"
  type        = string
  validation {
    condition     = contains(["shared", "workload"], var.account_type)
    error_message = "account_type must be either 'shared' or 'workload'."
  }
}

variable "workload_account_arns" {
  description = "List of workload account ARNs that can assume the shared account role"
  type        = list(string)
  default     = []
}

variable "allowed_environments" {
  description = "List of environments allowed to access shared resources"
  type        = list(string)
  default     = ["dev", "qa", "prod"]
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs to grant access to"
  type        = list(string)
  default     = []
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs to grant access to"
  type        = list(string)
  default     = []
}

variable "github_actions_role_arn" {
  description = "ARN of the GitHub Actions role that can assume this role"
  type        = string
  default     = ""
}

variable "shared_role_arn" {
  description = "ARN of the role in the shared account to assume"
  type        = string
  default     = ""
}

variable "kms_key_arns" {
  description = "List of KMS key ARNs for encryption/decryption"
  type        = list(string)
  default     = []
}

variable "cicd_principal_arns" {
  description = "List of CI/CD principal ARNs that need enhanced access"
  type        = list(string)
  default     = []
}

variable "additional_principal_arns" {
  description = "List of additional IAM principal ARNs that can assume the workload role"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}