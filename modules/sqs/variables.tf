variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule that will send messages to this queue"
  type        = string
}

variable "visibility_timeout" {
  description = "The visibility timeout for the queue in seconds"
  type        = number
  default     = 30
}

variable "retention_period" {
  description = "The number of seconds to retain a message"
  type        = number
  default     = 345600  # 4 days
}

variable "delay_seconds" {
  description = "The time in seconds that the delivery of all messages in the queue will be delayed"
  type        = number
  default     = 0
}

variable "max_message_size" {
  description = "The limit of how many bytes a message can contain"
  type        = number
  default     = 262144  # 256 KB
}

variable "enable_dlq" {
  description = "Enable Dead Letter Queue"
  type        = bool
  default     = true
}

variable "max_receive_count" {
  description = "Maximum number of receives before message goes to DLQ"
  type        = number
  default     = 3
}

variable "dlq_retention_period" {
  description = "How long to keep messages in DLQ"
  type        = number
  default     = 1209600  # 14 days
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "kms_key_id" {
  description = "ID of the KMS key for encryption"
  type        = string
}