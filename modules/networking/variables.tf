variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "karpenter_cluster_name" {
  description = "Name of the Karpenter-managed eks cluster"
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

variable "private_subnets" {
  description = "A list of private subnet cidr blocks"
  type        = list(string)
  default     = ["192.168.16.0/22", "192.168.20.0/22", "192.168.24.0/22", "192.168.4.0/24", "192.168.5.0/24", "192.168.6.0/24"]
}

