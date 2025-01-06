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
  description = "VPC ID where Aurora will be deployed"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for Aurora"
}

variable "lambda_security_group_id" {
  type        = string
  description = "Security group ID of Lambda functions"
}

variable "engine_version" {
  type        = string
  description = "Aurora PostgreSQL engine version"
  default     = "13.9"
}

variable "database_name" {
  type        = string
  description = "Name of the default database"
}

variable "master_username" {
  type        = string
  description = "Master username for the database"
  default     = "postgres"
}

variable "min_capacity" {
  type        = number
  description = "Minimum Aurora capacity units (ACUs)"
  default     = 0.5
}

variable "max_capacity" {
  type        = number
  description = "Maximum Aurora capacity units (ACUs)"
  default     = 16
}

variable "instance_count" {
  type        = number
  description = "Number of Aurora instances"
  default     = 1
}

variable "backup_retention_days" {
  type        = number
  description = "Number of days to retain backups"
  default     = 7
}

variable "backup_window" {
  type        = string
  description = "Preferred backup window"
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  type        = string
  description = "Preferred maintenance window"
  default     = "Mon:04:00-Mon:05:00"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags for resources"
  default     = {}
}