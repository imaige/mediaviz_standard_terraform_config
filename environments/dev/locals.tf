locals {
  # Get shared account data using terraform_remote_state
  shared_data = data.terraform_remote_state.shared.outputs

  # ECR repository ARNs from the shared account
  shared_ecr_repository_arns = values(local.shared_data.ecr_repository_arns)
  
  # ECR repository URLs from the shared account
  shared_ecr_repository_urls = local.shared_data.ecr_repository_urls
  
  # Mapping of repository types to their URLs in the shared account
  ecr_repository_mapping = {
    # Lambda repositories
    "l-blur-model"               = local.shared_ecr_repository_urls["l-blur-model"]
    "l-colors-model"             = local.shared_ecr_repository_urls["l-colors-model"]
    "l-image-comparison-model"   = local.shared_ecr_repository_urls["l-image-comparison-model"]
    "l-facial-recognition-model" = local.shared_ecr_repository_urls["l-facial-recognition-model"]
    
    # EKS repositories
    "eks-feature-extraction-model"   = local.shared_ecr_repository_urls["eks-feature-extraction-model"]
    "eks-image-classification-model" = local.shared_ecr_repository_urls["eks-image-classification-model"]
    "eks-mediaviz-external-api"      = local.shared_ecr_repository_urls["eks-mediaviz-external-api"]
    "eks-evidence-model"             = local.shared_ecr_repository_urls["eks-evidence-model"]
    "eks-similarity-model"           = local.shared_ecr_repository_urls["eks-similarity-model"]
    "eks-external-api"               = local.shared_ecr_repository_urls["eks-external-api"]
  }
}