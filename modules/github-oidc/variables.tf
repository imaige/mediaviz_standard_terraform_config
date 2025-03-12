# modules/github-oidc/variables.tf

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env" {
  description = "Environment (dev, qa, prod)"
  type        = string
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "account_type" {
  description = "Type of account (shared, workload)"
  type        = string
  default     = "workload"
  validation {
    condition     = contains(["shared", "workload"], var.account_type)
    error_message = "account_type must be either 'shared' or 'workload'."
  }
}

variable "cross_account_roles" {
  description = "List of cross-account role ARNs that GitHub Actions can assume"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}