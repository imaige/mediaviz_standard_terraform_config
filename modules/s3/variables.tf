variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env" {
  description = "Environment (dev, prod, etc)"
  type        = string
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "retention_days" {
  description = "Number of days to retain objects"
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
}

variable "replica_kms_key_id" {
  description = "KMS key ID for replica bucket encryption"
  type        = string
}