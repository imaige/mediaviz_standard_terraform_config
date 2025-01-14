# bastion/variables.tf
variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "env" {
  type        = string
  description = "Environment name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where bastion will be deployed"
}

variable "public_subnet_id" {
  type        = string
  description = "Public subnet ID where bastion will be deployed"
}

variable "key_name" {
  type        = string
  description = "Name of the EC2 key pair for bastion access"
  default     = "mediaviz-dev-bastion"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for bastion"
  default     = "t3.micro"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags for resources"
  default     = {}
}

variable "aurora_endpoint" {
  type        = string
  description = "Aurora cluster endpoint for tunnel command output"
}

variable "allowed_ips" {
  type        = list(string)
  description = "List of IP addresses allowed to access the bastion (in CIDR format)"
  default     = []
}