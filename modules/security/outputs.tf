output "signing_profile_arn" {
  value = aws_signer_signing_profile.lambda.arn
}

output "eks_admin_role_arn" {
  description = "ARN of the EKS administrator role"
  value       = aws_iam_role.eks_admin.arn
}

output "eks_admin_group_id" {
  description = "ID of the EKS administrators group"
  value       = aws_identitystore_group.eks_admins.group_id
}

output "eks_admin_permission_set_arn" {
  description = "ARN of the EKS administrator permission set"
  value       = aws_ssoadmin_permission_set.eks_admin.arn
}