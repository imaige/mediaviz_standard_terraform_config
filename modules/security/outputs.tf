output "signing_profile_arn" {
  value = aws_signer_signing_profile.lambda.arn
}

output "eks_admin_role_arn" {
  description = "ARN of the EKS administrator role"
  value       = aws_iam_role.eks_admin.arn
}

output "eks_admin_group_id" {
  description = "ID of the EKS admin group in AWS SSO"
  value       = length(aws_identitystore_group.eks_admins) > 0 ? aws_identitystore_group.eks_admins[0].group_id : null
}

output "eks_admin_permission_set_arn" {
  description = "ARN of the EKS admin permission set in AWS SSO"
  value       = length(aws_ssoadmin_permission_set.eks_admin) > 0 ? aws_ssoadmin_permission_set.eks_admin[0].arn : null
}