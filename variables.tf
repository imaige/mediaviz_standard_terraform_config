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
