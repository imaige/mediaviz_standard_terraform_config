variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "mediaviz"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-2"
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "workload_account_ids" {
  description = "Map of environment names to AWS account IDs"
  type        = map(string)
  default     = {
    dev  = ""
    qa   = ""
    prod = ""
  }
}

variable "ecr_repositories" {
  description = "List of ECR repositories to create"
  type        = list(string)
  default     = [
    "l-blur-model",
    "l-colors-model",
    "l-image-comparison-model",
    "l-facial-recognition-model",
    "eks-feature-extraction-model",
    "eks-image-classification-model",
    "eks-mediaviz-external-api",
    "eks-evidence-model",
    "eks-similarity-model",
    "eks-similarity-set-sorting-service",
  ]
}

variable "s3_buckets" {
  description = "Map of S3 bucket configurations"
  type = map(object({
    cors_allowed_origins = list(string)
    retention_days       = number
  }))
  default = {
    main = {
      cors_allowed_origins = ["*"]
      retention_days       = 30
    }
  }
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "workload_environments" {
  description = "List of environment names corresponding to workload account IDs"
  type        = list(string)
  default     = ["qa", "dev", "prod"]  # Must be in same order as workload_account_ids values
}