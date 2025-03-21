# ../../modules/eks_processors/outputs.tf

output "repository_urls" {
  description = "URLs of the ECR repositories (now using shared repositories)"
  value = {
    for k, v in local.models : k => "${var.shared_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-shared-eks-${k}"
  }
}

output "repository_arns" {
  description = "ARNs of the ECR repositories (now using shared repositories)"
  value = {
    for k, v in local.models : k => "arn:aws:ecr:${var.aws_region}:${var.shared_account_id}:repository/${var.project_name}-shared-eks-${k}"
  }
}

output "role_arns" {
  description = "ARNs of the IAM roles for each model"
  value = {
    for k, v in aws_iam_role.model_role : k => v.arn
  }
}