variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env" {
  description = "Environment (dev, qa, prod)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster will be created"
  type        = string
}

variable "subnet_ids" {
  description = "A list of subnet IDs for the EKS cluster nodes"
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "A list of subnet IDs for the EKS control plane"
  type        = list(string)
}

variable "eks_admin_role_arn" {
  description = "ARN of the IAM role for EKS administrator access"
  type        = string
}

variable "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role for CI/CD"
  type        = string
  default     = ""
}

variable "aws_account_id" {
  description = "AWS account ID where resources are deployed"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources are deployed"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for EKS encryption"
  type        = string
}

variable "kms_key_arns" {
  description = "List of KMS key ARNs that the EKS nodes need access to"
  type        = list(string)
  default     = []
}

variable "cloudwatch_logs_kms_key_arn" {
  description = "ARN of the KMS key for CloudWatch logs encryption"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 365
}

variable "eks_primary_instance_type" {
  description = "Instance type for the EKS primary node group"
  type        = list(string)
  default     = ["m5.large", "m5a.large"]
}

variable "node_group_min_size" {
  description = "Minimum size of the primary node group"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum size of the primary node group"
  type        = number
  default     = 6
}

variable "node_group_desired_size" {
  description = "Desired size of the primary node group"
  type        = number
  default     = 3
}

variable "gpu_instance_types" {
  description = "Instance types for the GPU node group"
  type        = list(string)
  default     = ["g4dn.xlarge", "g4dn.2xlarge"]
}

variable "gpu_node_min_size" {
  description = "Minimum size of the GPU node group"
  type        = number
  default     = 0
}

variable "gpu_node_max_size" {
  description = "Maximum size of the GPU node group"
  type        = number
  default     = 10
}

variable "gpu_node_desired_size" {
  description = "Desired size of the GPU node group"
  type        = number
  default     = 0
}

variable "enable_fargate" {
  description = "Whether to enable Fargate profiles for the cluster"
  type        = bool
  default     = false
}

variable "install_nvidia_plugin" {
  description = "Whether to install NVIDIA device plugin for GPU support"
  type        = bool
  default     = true
}

variable "nvidia_plugin_version" {
  description = "Version of the NVIDIA device plugin Helm chart"
  type        = string
  default     = "0.17.0"
}

variable "aurora_cluster_arns" {
  description = "List of Aurora cluster ARNs that the EKS nodes need access to"
  type        = list(string)
  default     = []
}

variable "sqs_queue_arns" {
  description = "List of SQS queue ARNs that the EKS nodes need access to"
  type        = list(string)
  default     = []
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs that the EKS nodes need access to"
  type        = list(string)
  default     = []
}

variable "enable_shared_access" {
  description = "Whether to enable access to shared account resources"
  type        = bool
  default     = false
}

variable "shared_access_role_arn" {
  description = "ARN of the role in the shared account to assume"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "create_developer_role" {
  description = "Whether to create a developer role with limited permissions"
  type        = bool
  default     = false
}