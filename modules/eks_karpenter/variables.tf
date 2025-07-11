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
  default     = "1.32"
}

variable "karpenter_cluster_version" {
  description = "Kubernetes version for the Karpenter EKS cluster"
  type        = string
  default     = "1.33"
}

variable "namespace" {
  description = "Kubernetes namespace for deployments"
  type        = string
  default     = "default"
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

variable "kms_key_access" {
  description = "General access to KMS"
  type        = string
  default     = ""
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
  default     = "0.17.1"
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

variable "create_kubernetes_resources" {
  description = "Whether to create Kubernetes resources like service accounts and Helm charts"
  type        = bool
  default     = false
}

variable "additional_access_entries" {
  description = "Additional IAM principals to grant access to the EKS cluster"
  type = map(object({
    kubernetes_groups = list(string)
    principal_arn     = string
    type              = string
  }))
  default = {}
}

variable "evidence_gpu_instance_types" {
  description = "Instance types for the evidence model GPU node group"
  type        = list(string)
  default     = ["g5.4xlarge"]
}

variable "evidence_gpu_node_min_size" {
  description = "Minimum size of the evidence GPU node group"
  type        = number
  default     = 3
}

variable "evidence_gpu_node_max_size" {
  description = "Maximum size of the evidence GPU node group"
  type        = number
  default     = 5

}

variable "evidence_gpu_node_desired_size" {
  description = "Desired size of the evidence GPU node group"
  type        = number
  default     = 3
}

variable "nodegroup_version" {
  description = "Version suffix for nodegroups to force recreation when subnets change"
  type        = string
  default     = "v2"
}

variable "evidence_gpu_nodepool_capacity_type" {
  description = "Capacity type for the evidence GPU node group"
  type        = list(string)
  default     = ["on-demand"]
}

variable "evidence_gpu_nodepool_max_cpu" {
  description = "Maximum CPU limit for evidence nodes"
  type        = number
  default     = 64
}

variable "evidence_gpu_nodepool_max_mem" {
  description = "Maximum memory limit for evidence nodes"
  type        = string
  default     = "256Gi"
}

variable "primary_nodepool_capacity_type" {
  description = "Capacity type for the primary node group"
  type        = list(string)
  default     = ["on-demand"]
}

variable "primary_nodepool_max_cpu" {
  description = "Maximum CPU limit for primary nodes"
  type        = number
  default     = 64
}

variable "primary_nodepool_max_mem" {
  description = "Maximum memory limit for primary nodes"
  type        = string
  default     = "256Gi"
}

variable "node_secrets_policy_metadata" {
  description = "name and description of the eks node policy"
}

variable "shared_account_id" {
  description = "AWS account ID of the shared services account"
  type        = string
}

variable "models" {
  description = "The models being deployed to Kubernetes"
  type        = map(any)
  default     = { "evidence-model" = { needs_sqs = true } }
}

variable "evidence_gpu_ami_selector" {
  description = "The ami for the high-power GPU nodeclass"
  type        = string
  default     = "amazon-eks-node-al2023-x86_64-nvidia"
}
