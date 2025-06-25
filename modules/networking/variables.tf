variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "env" {
  description = "Environment name (dev, prod, etc)"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
