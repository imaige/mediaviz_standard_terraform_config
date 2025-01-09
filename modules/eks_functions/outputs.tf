output "ecr_repository_urls" {
  description = "URLs of the created ECR repositories"
  value       = aws_ecr_repository.repositories[*].repository_url
}

output "deployment_names" {
  description = "Names of the Kubernetes deployments"
  value       = kubernetes_deployment.eks_functions[*].metadata[0].name
}
