# existing vars, plus anything else not specified
// variables.tf
variable "env" {
  description = "The environment name (e.g., dev, qa, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "aws_region" {
  description = "The region name"
  type        = string
  default     = "dev"
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
  default     = "dev"
}

variable "eks_primary_instance_type" {
  description = "The region name"
  type        = list(string)
  default     = ["t3.medium"]
}