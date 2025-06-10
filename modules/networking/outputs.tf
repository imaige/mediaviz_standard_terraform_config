output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "The IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "The IDs of the public subnets"
  value       = module.vpc.public_subnets
}

# Aurora will use the /24 subnets (indices 3, 4, 5)
output "aurora_subnets" {
  description = "The IDs of the private subnets for Aurora (/24 subnets)"
  value       = slice(module.vpc.private_subnets, 3, 6)
}

# EKS will use the /22 subnets (indices 0, 1, 2)
output "eks_subnets" {
  description = "The IDs of the private subnets for EKS (/22 subnets)"
  value       = slice(module.vpc.private_subnets, 0, 3)
}