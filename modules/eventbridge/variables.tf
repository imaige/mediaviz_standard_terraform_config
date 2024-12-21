variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "target_arn" {
  description = "ARN of the target service (SQS, Lambda, etc)"
  type        = string
}