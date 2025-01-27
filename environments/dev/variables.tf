variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "env" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "mediaviz"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "379283424934" # Your current AWS account ID
}

variable "eks_primary_instance_type" {
  description = "Instance type for the EKS node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_managed_node_groups" {
  description = "Map of EKS managed node group configurations"
  type        = map(any)
  default = {
    primary_node_group = {
      min_size       = 3
      max_size       = 10
      desired_size   = 3
      instance_types = ["t3.medium"]
    }
  }
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "cluster_addons" {
  description = "Map of cluster addon configurations"
  type        = map(any)
  default = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default = {
    environment = "dev"
    terraform   = "true"
    project     = "mediaviz"
  }
}

# Optional: Add if you need different node group sizes per environment
variable "node_group_min_size" {
  description = "Minimum size of the EKS node group"
  type        = number
  default     = 3
}

variable "node_group_max_size" {
  description = "Maximum size of the EKS node group"
  type        = number
  default     = 10
}

variable "node_group_desired_size" {
  description = "Desired size of the EKS node group"
  type        = number
  default     = 3
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "retention_days" {
  description = "Number of days to retain objects in S3"
  type        = number
  default     = 30
}

# Add these new variables for serverless infrastructure

variable "lambda_memory_size" {
  description = "Memory size for Lambda function"
  type        = number
  default     = 1024
}

variable "lambda_timeout" {
  description = "Timeout for Lambda function in seconds"
  type        = number
  default     = 30
}

variable "lambda_runtime" {
  description = "Runtime for Lambda function"
  type        = string
  default     = "python3.9"
}

variable "lambda_storage_size" {
  description = "Ephemeral storage size for Lambda function in MB"
  type        = number
  default     = 512
}

variable "sqs_message_retention_seconds" {
  description = "The number of seconds SQS retains a message"
  type        = number
  default     = 345600 # 4 days
}

variable "sqs_visibility_timeout_seconds" {
  description = "The visibility timeout for the queue in seconds"
  type        = number
  default     = 30
}

variable "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
  default     = "v1"
}

variable "eventbridge_rule_description" {
  description = "Description for EventBridge rule"
  type        = string
  default     = "Process new image uploads from S3"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "mediaviz-serverless" # This differentiates it from your EKS resources
}

# variable "encrypted_env_var" {
#   description = "Encrypted environment variable for Lambda function"
#   type        = string
# }
