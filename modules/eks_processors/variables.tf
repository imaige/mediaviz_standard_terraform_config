variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env" {
  description = "Environment (dev, qa, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources are deployed"
  type        = string
}

variable "shared_account_id" {
  description = "AWS account ID of the shared services account"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for deployments"
  type        = string
  default     = "default"
}

variable "chart_version" {
  description = "Version of the Helm chart to deploy"
  type        = string
  default     = "0.1.0"
}

variable "replicas" {
  description = "Number of replicas for each deployment"
  type        = number
  default     = 1
}

variable "sqs_queues" {
  description = "Map of model names to their SQS queue URLs"
  type        = map(string)
  default     = {}
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs that models need access to"
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "oidc_provider" {
  description = "OIDC provider URL for the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN for the EKS cluster"
  type        = string
}

variable "aurora_cluster_arn" {
  description = "ARN of the Aurora cluster"
  type        = string
}

variable "aurora_secret_arn" {
  description = "ARN of the Aurora secret in Secrets Manager"
  type        = string
}

variable "aurora_database_name" {
  description = "Name of the Aurora database"
  type        = string
}

variable "cross_account_arns" {
  description = "List of cross-account ARNs for resource access"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}