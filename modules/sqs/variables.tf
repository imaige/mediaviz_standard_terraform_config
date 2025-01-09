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

variable "source_arns" {
  type        = list(string)
  description = "List of ARNs that can send messages to the queues (EventBridge rules, Lambda functions)"
  default     = []
}

variable "lambda_role_arns" {
  type        = list(string)
  description = "List of Lambda role ARNs that need access to the queues"
  default     = []
}

variable "eks_role_arn" {
  type        = string
  description = "EKS IAM role ARN that needs access to the queues"
  default     = null
}

# Optional KMS configuration
variable "kms_key_id" {
  type        = string
  description = "The ID of an AWS-managed customer master key for Amazon SQS or a custom CMK"
  default     = null
}

variable "use_kms_encryption" {
  type        = bool
  description = "Whether to use KMS encryption instead of SQS-managed encryption"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to add to all resources"
  default     = {}
}

# Module-specific settings
variable "module_specific_config" {
  type = map(object({
    visibility_timeout = optional(number)
    max_receive_count = optional(number)
    delay_seconds    = optional(number)
    policy_statements = optional(list(any))
  }))
  description = "Module-specific configurations for each processing queue"
  default     = {}
}