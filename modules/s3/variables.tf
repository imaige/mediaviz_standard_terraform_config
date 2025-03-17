variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env" {
  description = "Environment (dev, qa, prod, shared)"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for S3 encryption"
  type        = string
}

variable "kms_key_id" {
  description = "ID of the KMS key for S3 encryption"
  type        = string
}

variable "cors_allowed_origins" {
  description = "List of origins allowed for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "retention_days" {
  description = "Number of days to retain objects before deletion"
  type        = number
  default     = 30
}

variable "cross_account_arns" {
  description = "List of ARNs for cross-account access (read-only)"
  type        = list(string)
  default     = []
}

variable "ci_cd_role_arns" {
  description = "List of CI/CD role ARNs for read/write access"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "bucket_suffix" {
  description = "Suffix to add to bucket names for uniqueness"
  type        = string
  default     = ""
}

variable "helm_charts_bucket_name" {
  description = "Custom name for the Helm charts bucket"
  type        = string
  default     = ""
}