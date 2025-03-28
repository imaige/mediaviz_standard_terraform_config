# Existing Infrastructure
module "vpc" {
  source = "./../../modules/networking"

  cluster_name = var.cluster_name
  env          = var.env
}

module "security" {
  source = "./../../modules/security"

  project_name = var.project_name
  env          = var.env
  kms_key_arn  = null  # Will be created by the module
  kms_key_id   = null  # Will be created by the module
  cluster_name = var.cluster_name  # Reference before creation, will be updated
  enable_sso   = false
  github_actions_role_arn = module.github_oidc.role_arn
  
  tags = var.tags
}

module "eks" {
  source = "./../../modules/eks"

  project_name    = var.project_name
  cluster_name    = var.cluster_name
  env             = var.env
  cluster_version = var.cluster_version
  aws_region      = data.aws_region.current.name

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  eks_primary_instance_type = var.eks_primary_instance_type
  node_group_min_size       = var.node_group_min_size
  node_group_max_size       = var.node_group_max_size
  node_group_desired_size   = var.node_group_desired_size
  
  # Use GPU instance types variable
  gpu_instance_types       = var.gpu_instance_types
  gpu_node_min_size        = var.gpu_node_min_size
  gpu_node_max_size        = var.gpu_node_max_size
  gpu_node_desired_size    = var.gpu_node_desired_size

  aws_account_id     = data.aws_caller_identity.current.account_id
  kms_key_arn        = module.security.kms_key_arn
  eks_admin_role_arn = module.security.eks_admin_role_arn
  
  # Add SQS, S3, and Aurora access
  sqs_queue_arns = values(module.sqs.lambda_queue_arns)
  s3_bucket_arns = [
    module.s3.bucket_arn,
    "${module.s3.bucket_arn}/*"
  ]
  aurora_cluster_arns = [module.aurora.cluster_arn]
  
  # Cross account access
  enable_shared_access = true
  shared_access_role_arn = module.cross_account_roles.role_arn
  
  
  install_nvidia_plugin = true
  create_kubernetes_resources = true
  
  tags = var.tags
}

# New Serverless Infrastructure
module "s3" {
  source = "./../../modules/s3"

  project_name         = var.project_name
  env                  = var.env
  cors_allowed_origins = var.cors_allowed_origins
  retention_days       = var.retention_days
  kms_key_arn          = module.security.kms_key_arn
  kms_key_id           = module.security.kms_key_id
  cross_account_arns   = []  # No cross-account access needed for this bucket
  
  tags = var.tags
}

module "lambda_upload" {
  source = "./../../modules/lambda_upload"

  project_name = var.project_name
  env          = var.env

  s3_bucket_name = module.s3.bucket_id
  s3_bucket_arn  = module.s3.bucket_arn

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  kms_key_arn = module.security.kms_key_arn
  kms_key_id  = module.security.kms_key_id

  aurora_cluster_arn   = module.aurora.cluster_arn
  aurora_secret_arn    = module.aurora.secret_arn
  aurora_database_name = module.aurora.database_name
  aurora_kms_key_arn   = module.aurora.kms_key_arn

  tags = var.tags
}

module "lambda_processors" {
  source = "./../../modules/lambda_processors"

  project_name = var.project_name
  env          = var.env
  aws_region   = data.aws_region.current.name

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  # ECR configurations - use shared account repositories
  ecr_repository_url  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${var.project_name}-${var.env}"
  shared_ecr_repository_url = "${data.terraform_remote_state.shared.outputs.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${var.project_name}-shared"
  ecr_repository_arns = local.shared_ecr_repository_arns
  
  # S3 buckets that Lambda needs access to
  s3_bucket_arns = [
    module.s3.bucket_arn,
    # Access to shared account helm charts bucket
    data.terraform_remote_state.shared.outputs.s3_helm_charts_bucket.arn
  ]

  # SQS configurations 
  sqs_queues = {
    l-blur-model               = module.sqs.lambda_queue_arns["lambda-blur-model"]
    l-colors-model             = module.sqs.lambda_queue_arns["lambda-colors-model"]
    l-image-comparison-model   = module.sqs.lambda_queue_arns["lambda-image-comparison-model"]
    l-facial-recognition-model = module.sqs.lambda_queue_arns["lambda-facial-recognition-model"]
  }
  dlq_arn = module.sqs.dlq_arn

  # Aurora configurations
  aurora_cluster_arn       = module.aurora.cluster_arn
  aurora_secret_arn        = module.aurora.secret_arn
  aurora_database_name     = module.aurora.database_name
  aurora_security_group_id = module.aurora.security_group_id
  aurora_kms_key_arn       = module.aurora.kms_key_arn

  # Lambda scaling and concurrency
  batch_size       = 1
  batch_window     = 0
  max_concurrency  = 10
  
  tags = var.tags
}

module "api_gateway" {
  source = "./../../modules/api_gateway"

  project_name         = var.project_name
  env                  = var.env
  lambda_invoke_arn    = module.lambda_upload.invoke_arn
  lambda_function_name = module.lambda_upload.function_name
  kms_key_arn          = module.security.kms_key_arn
  kms_key_id           = module.security.kms_key_id
  waf_acl_arn          = module.security.waf_acl_arn
  
}

module "eventbridge" {
  source = "./../../modules/eventbridge"

  project_name = var.project_name
  env          = var.env

  sqs_queues = {
    l-blur-model                 = module.sqs.lambda_queue_arns["lambda-blur-model"]
    l-colors-model               = module.sqs.lambda_queue_arns["lambda-colors-model"]
    l-image-comparison-model     = module.sqs.lambda_queue_arns["lambda-image-comparison-model"]
    l-facial-recognition-model   = module.sqs.lambda_queue_arns["lambda-facial-recognition-model"]
    eks-image-classification-model = module.sqs.eks_queue_arns["eks-image-classification-model"]
    eks-feature-extraction-model = module.sqs.eks_queue_arns["eks-feature-extraction-model"]
  }

  dlq_arn = module.sqs.dlq_arn
  tags    = var.tags
}

module "sqs" {
  source = "./../../modules/sqs"

  project_name = var.project_name
  env          = var.env

  # Base configuration
  visibility_timeout = 300 # 5 minutes
  enable_dlq         = true
  max_receive_count  = 3

  # Source ARNs
  source_arns = concat(
    [module.lambda_upload.function_arn],
    module.eventbridge.event_bus_rule_arns
  )

  # Access permissions
  lambda_role_arns = module.lambda_processors.all_role_arns
  eks_role_arn     = module.eks.node_group_role_arn

  # Optional: Module-specific configurations
  model_specific_config = {
    "lambda-module1" = {
      visibility_timeout = 600 # 10 minutes for longer processing
      max_receive_count  = 5
    }
    "eks-module2" = {
      delay_seconds = 10 # Add delay for this specific module
    }
  }

  # Optional: KMS encryption
  use_kms_encryption = true
  kms_key_id         = module.security.kms_key_id

  tags = var.tags
}

module "aurora" {
  source = "./../../modules/aurora"

  project_name = var.project_name
  env          = var.env
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnets

  database_name              = "imaige"
  lambda_security_group_id   = module.lambda_processors.all_security_group_ids[0]
  engine_version             = "16.3"
  publicly_accessible        = true
  eks_node_security_group_id = module.eks.node_security_group_id

  min_capacity = 0.5
  max_capacity = 16

  tags = var.tags
}

module "bastion" {
  source = "./../../modules/bastion"

  project_name     = var.project_name
  env              = var.env
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnets[0]
  allowed_ips      = var.bastion_allowed_ips
  aurora_endpoint  = module.aurora.cluster_endpoint
  
  tags = var.tags
}

# Remove the ECR module in workload accounts - use shared account ECR instead
# module "ecr" {
#   source = "./../../modules/ecr"
#   ...
# }

module "eks_processors" {
  source = "./../../modules/eks_processors"

  project_name = var.project_name
  env          = var.env
  aws_region   = data.aws_region.current.name
  
  # Add this variable
  shared_account_id = data.terraform_remote_state.shared.outputs.account_id

  aurora_cluster_arn   = module.aurora.cluster_arn
  aurora_secret_arn    = module.aurora.secret_arn
  aurora_database_name = module.aurora.database_name

  namespace     = "default"
  chart_version = "0.1.0"
  replicas      = 1

  sqs_queues = {
    "feature-extraction-model"   = module.sqs.eks_queue_urls["eks-feature-extraction-model"]
    "image-classification-model" = module.sqs.eks_queue_urls["eks-image-classification-model"]
  }

  kms_key_arn       = module.security.kms_key_arn
  oidc_provider     = module.eks.oidc_provider
  oidc_provider_arn = module.eks.oidc_provider_arn
  
  # Keep these existing parameters
  cross_account_arns = [
    data.terraform_remote_state.shared.outputs.cross_account_role_arn
  ]
  
  s3_bucket_arns = [
    data.terraform_remote_state.shared.outputs.s3_helm_charts_bucket.arn,
    "${data.terraform_remote_state.shared.outputs.s3_helm_charts_bucket.arn}/*"
  ]

  tags = var.tags
}

module "cross_account_roles" {
  source = "../../modules/cross-account-roles"
  
  project_name = var.project_name
  account_type = "workload"
  env          = var.env
  
  # Use OIDC provider ARN from GitHub Actions
  github_actions_role_arn = module.github_oidc.role_arn
  
  # Reference shared account role using remote state
  shared_role_arn = data.terraform_remote_state.shared.outputs.cross_account_role_arn
  
  # Access specific ECR repositories
  ecr_repository_arns = [
    for repo in var.shared_ecr_repositories : 
    "arn:aws:ecr:${data.aws_region.current.name}:${data.terraform_remote_state.shared.outputs.account_id}:repository/${var.project_name}-shared-${repo}"
  ]
  
  # Access shared S3 buckets
  s3_bucket_arns = [
    data.terraform_remote_state.shared.outputs.s3_helm_charts_bucket.arn,
    "${data.terraform_remote_state.shared.outputs.s3_helm_charts_bucket.arn}/*"
  ]
  
  # Add KMS keys
  kms_key_arns = [
    data.terraform_remote_state.shared.outputs.kms_key_arn
  ]
  
  tags = var.tags
}

module "github_oidc" {
  source = "../../modules/github-oidc"
  
  project_name = var.project_name
  env          = var.env
  github_org   = var.github_org
  github_repo  = var.github_repo
  account_type = "workload"
  aws_region   = data.aws_region.current.name
  aws_account_id = data.aws_caller_identity.current.account_id
  
  # Add KMS key ARNs
  kms_key_arns = [module.security.kms_key_arn]
  
  # Access to shared ECR repositories
  shared_ecr_arns = [
    for repo in var.shared_ecr_repositories : 
    "arn:aws:ecr:${data.aws_region.current.name}:${data.terraform_remote_state.shared.outputs.account_id}:repository/${var.project_name}-shared-${repo}"
  ]
  
  # Access to shared S3 buckets
  shared_s3_arns = [
    data.terraform_remote_state.shared.outputs.s3_helm_charts_bucket.arn,
    "${data.terraform_remote_state.shared.outputs.s3_helm_charts_bucket.arn}/*"
  ]
  
  # Cross-account role to assume
  cross_account_roles = [
    data.terraform_remote_state.shared.outputs.cross_account_role_arn
  ]
  
  enable_cicd_permissions = true
  
  tags = var.tags
}

# Define locals for shared account resources
locals {
  shared_account_id = data.terraform_remote_state.shared.outputs.account_id
  
  # Convert shared ECR repository ARNs to a list
  shared_ecr_repository_arns = [
    for repo in var.shared_ecr_repositories : 
    "arn:aws:ecr:${data.aws_region.current.name}:${local.shared_account_id}:repository/${var.project_name}-shared-${repo}"
  ]
}