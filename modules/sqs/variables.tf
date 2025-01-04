# sqs/variables.tf

variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "env" {
  type        = string
  description = "Environment name"
}

variable "visibility_timeout" {
  type        = number
  description = "The visibility timeout for the queue in seconds"
  default     = 180  # Should match or exceed Lambda timeout
}

variable "retention_period" {
  type        = number
  description = "The number of seconds the queue retains a message"
  default     = 345600  # 4 days
}

variable "delay_seconds" {
  type        = number
  description = "The time in seconds that the delivery of all messages in the queue is delayed"
  default     = 0
}

variable "max_message_size" {
  type        = number
  description = "The limit of how many bytes a message can contain"
  default     = 262144  # 256 KiB
}

variable "enable_dlq" {
  type        = bool
  description = "Enable Dead Letter Queue"
  default     = true
}

variable "max_receive_count" {
  type        = number
  description = "Maximum number of times a message can be received before being sent to the DLQ"
  default     = 3
}

variable "dlq_retention_period" {
  type        = number
  description = "How long messages should be kept in the DLQ"
  default     = 1209600  # 14 days
}

variable "lambda_role_arns" {
  type        = list(string)
  description = "List of Lambda role ARNs that need access to the queue"
  default     = []
}

# variable "kms_key_id" {
#   type        = string
#   description = "KMS key ID for queue encryption"
#   default     = null
# }

variable "tags" {
  type        = map(string)
  description = "Additional tags for resources"
  default     = {}
}

variable "source_arns" {
  type        = list(string)
  description = "List of ARNs that can send messages to the queue (EventBridge rules, Lambda functions)"
  default     = []
}