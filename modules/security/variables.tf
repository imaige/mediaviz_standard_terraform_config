variable "kms_key_arn" {
  description = "ARN of KMS key for encryption"
  type        = string
}

variable "kms_key_id" {
  description = "ID of KMS key for encryption"
  type        = string
}

variable "eks_node_role_arn" {
  description = "ARN of the EKS node IAM role"
  type        = string
  default     = null # Makes it optional
}
variable "tags" {
  default = {}
}
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}