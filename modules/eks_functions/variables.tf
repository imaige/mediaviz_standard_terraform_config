variable "models" {
  description = "List of model names for the EKS functions"
  type        = list(string)
}

variable "prefix" {
  description = "Prefix for naming resources"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the deployments"
  type        = string
}

variable "replicas" {
  description = "Number of replicas for each deployment"
  type        = number
  default     = 3
}

variable "sqs_urls" {
  description = "List of SQS URLs corresponding to each model"
  type        = list(string)
}

variable "sqs_arns" {
  description = "List of SQS ARNs for IAM access"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS Region for the ECR repositories and SQS"
  type        = string
}

variable "image_tags" {
  description = "List of image tags for the ECR repositories"
  type        = list(string)
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account for the pods"
  type        = string
}
