variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env" {
  description = "Environment (dev, qa, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for deployments"
  type        = string
  default     = "default"
}

variable "sqs_queues" {
  description = "Map of SQS queue URLs for EKS processors"
  type        = map(string)
  default     = {}
}

variable "oidc_provider" {
  description = "OIDC provider URL for EKS"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN for EKS"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption"
  type        = string
}

variable "aurora_cluster_arn" {
  description = "ARN of the Aurora cluster"
  type        = string
}

variable "aurora_secret_arn" {
  description = "ARN of the Aurora secret"
  type        = string
}

variable "aurora_database_name" {
  description = "Name of the Aurora database"
  type        = string
}

# Shared services variables
variable "shared_account_id" {
  description = "AWS account ID of the shared services account"
  type        = string
}

variable "shared_role_arn" {
  description = "ARN of the IAM role in the shared account that can be assumed"
  type        = string
  default     = ""
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs to grant access to (including shared buckets)"
  type        = list(string)
  default     = []
}

# Helm deployment variables
variable "enable_helm_deployments" {
  description = "Whether to enable Helm deployments"
  type        = bool
  default     = false
}

variable "helm_repository" {
  description = "Helm chart repository URL"
  type        = string
  default     = "https://charts.bitnami.com/bitnami" # Example default
}

variable "helm_chart_name" {
  description = "Name of the Helm chart to deploy"
  type        = string
  default     = "nginx" # Example default
}

variable "helm_chart_version" {
  description = "Version of the Helm chart to deploy"
  type        = string
  default     = ""
}

variable "helm_timeout" {
  description = "Timeout for Helm operations in seconds"
  type        = number
  default     = 300
}

variable "image_tag" {
  description = "Tag of the container images to deploy"
  type        = string
  default     = "latest"
}

variable "replicas" {
  description = "Number of replicas for each deployment"
  type        = number
  default     = 1
}

variable "model_replicas" {
  description = "Number of replicas for each model deployment"
  type        = map(number)
  default     = {}
}

# Resource requests and limits
variable "cpu_request" {
  description = "CPU request for each pod"
  type        = string
  default     = "100m"
}

variable "memory_request" {
  description = "Memory request for each pod"
  type        = string
  default     = "128Mi"
}

variable "cpu_limit" {
  description = "CPU limit for each pod"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for each pod"
  type        = string
  default     = "512Mi"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_shared_role_assumption" {
  description = "Whether to create IAM policies for assuming the shared role"
  type        = bool
  default     = false
}