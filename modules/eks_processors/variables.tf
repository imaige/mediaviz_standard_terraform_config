# modules/eks_processors/variables.tf

variable "project_name" {
 description = "Name of the project"
 type        = string
}

variable "env" {
 description = "Environment (dev, staging, prod)"
 type        = string
}

variable "aws_region" {
 description = "AWS region"
 type        = string
}

variable "namespace" {
 description = "Kubernetes namespace to deploy to"
 type        = string
 default     = "default"
}

variable "chart_version" {
 description = "Version of the Helm chart"
 type        = string
 default     = "0.1.0"
}

variable "replicas" {
 description = "Number of replicas for each model"
 type        = number
 default     = 2
}

variable "sqs_queues" {
 description = "Map of model names to their SQS queue ARNs"
 type        = map(string)
}

variable "kms_key_arn" {
 description = "ARN of KMS key for encryption"
 type        = string
}

variable "oidc_provider" {
 description = "OIDC provider URL for the EKS cluster"
 type        = string
}

variable "oidc_provider_arn" {
 description = "ARN of the OIDC provider for the EKS cluster"
 type        = string
}

variable "tags" {
 description = "Tags to apply to resources"
 type        = map(string)
 default     = {}
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

variable "cross_account_arns" {
  description = "List of ARNs for cross-account access to ECR repositories"
  type        = list(string)
  default     = []
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs that the models need access to"
  type        = list(string)
  default     = []
}