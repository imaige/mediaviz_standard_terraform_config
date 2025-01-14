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
