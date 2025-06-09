variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env" {
  description = "Environment (dev, qa, prod)"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 365
}

variable "notification_destinations" {
  description = "List of notification destinations for Grafana alerts"
  type        = list(string)
  default     = ["SNS"]
}


variable "create_prometheus_datasource" {
  description = "Whether to create Prometheus data source in Grafana"
  type        = bool
  default     = true
}

variable "api_key_seconds_to_live" {
  description = "Seconds to live for Grafana API key"
  type        = number
  default     = 2592000 # 30 days
}

variable "enable_eks_integration" {
  description = "Whether to enable EKS integration with Prometheus"
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for EKS"
  type        = string
  default     = ""
}

variable "oidc_provider" {
  description = "OIDC provider URL for EKS (without https://)"
  type        = string
  default     = ""
}

variable "prometheus_namespace" {
  description = "Kubernetes namespace for Prometheus"
  type        = string
  default     = "amazon-cloudwatch"
}

variable "prometheus_service_account" {
  description = "Kubernetes service account for Prometheus"
  type        = string
  default     = "cloudwatch-agent"
}

variable "enable_cloudwatch_alarms" {
  description = "Whether to enable CloudWatch alarms for monitoring"
  type        = bool
  default     = true
}

variable "cloudwatch_alarm_actions" {
  description = "List of actions to execute when CloudWatch alarms trigger"
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "VPC ID for security group (optional)"
  type        = string
  default     = ""
}

variable "grafana_allowed_cidrs" {
  description = "List of CIDR blocks allowed to access Grafana"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "deploy_prometheus_to_eks" {
  description = "Whether to deploy Prometheus to EKS cluster via Helm"
  type        = bool
  default     = true
}

variable "prometheus_chart_version" {
  description = "Version of the Prometheus Helm chart"
  type        = string
  default     = "25.27.0"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}