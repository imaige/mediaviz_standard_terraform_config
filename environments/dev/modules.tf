# Existing Infrastructure
module "vpc" {
  source = "./../../modules/networking"

  private_subnets = ["192.168.4.0/24", "192.168.5.0/24", "192.168.6.0/24"]

  cluster_name = var.cluster_name
  env          = var.env
  tags         = var.tags
}

module "security" {
  source = "./../../modules/security"

  project_name            = var.project_name
  env                     = var.env
  kms_key_arn             = null             # Will be created by the module
  kms_key_id              = null             # Will be created by the module
  cluster_name            = var.cluster_name # Reference before creation, will be updated
  enable_sso              = false
  github_actions_role_arn = module.github_oidc.role_arn

  project_suffix = "-serverless"

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
  gpu_instance_types    = var.gpu_instance_types
  gpu_node_min_size     = var.gpu_node_min_size
  gpu_node_max_size     = var.gpu_node_max_size
  gpu_node_desired_size = var.gpu_node_desired_size

  # Evidence model dedicated GPU nodes
  evidence_gpu_instance_types    = var.evidence_gpu_instance_types
  evidence_gpu_node_min_size     = var.evidence_gpu_node_min_size
  evidence_gpu_node_max_size     = var.evidence_gpu_node_max_size
  evidence_gpu_node_desired_size = var.evidence_gpu_node_desired_size

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
  enable_shared_access   = true
  shared_access_role_arn = module.cross_account_roles.role_arn

  # Enable developer role for MediavizDevelopers group
  create_developer_role = true

  install_nvidia_plugin       = true
  create_kubernetes_resources = true

  additional_access_entries = {
    caleb_sso = {
      kubernetes_groups = ["cluster-admin"] # Changed from system:masters
      principal_arn     = "arn:aws:iam::515966522375:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_e2f331b752f1e129"
      type              = "STANDARD"
    },
    dmitrii_sso = {
      kubernetes_groups = ["cluster-admin"] # Changed from system:masters
      principal_arn     = "arn:aws:iam::515966522375:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AWSAdministratorAccess_472a40aff28af737"
      type              = "STANDARD"
    },
    mediaviz_developers = {
      kubernetes_groups = ["MediavizDevelopers"]
      principal_arn     = "arn:aws:iam::515966522375:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_MediavizDevelopersPermissions_1b02cabbd428e5e0"
      type              = "STANDARD"
    }
  node_secrets_policy_metadata = {
    name        = "${var.project_name}-${var.env}-node-secrets-access"
    description = "Policy allowing EKS nodes to access all secrets, KMS, and SQS"
  }

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
  cross_account_arns   = [] # No cross-account access needed for this bucket

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
  ecr_repository_url        = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${var.project_name}-${var.env}"
  shared_ecr_repository_url = "${data.terraform_remote_state.shared.outputs.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${var.project_name}-shared"
  ecr_repository_arns       = local.shared_ecr_repository_arns

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
  batch_size      = 1
  batch_window    = 0
  max_concurrency = 1000

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
    l-blur-model                   = module.sqs.lambda_queue_arns["lambda-blur-model"]
    l-colors-model                 = module.sqs.lambda_queue_arns["lambda-colors-model"]
    l-image-comparison-model       = module.sqs.lambda_queue_arns["lambda-image-comparison-model"]
    l-facial-recognition-model     = module.sqs.lambda_queue_arns["lambda-facial-recognition-model"]
    eks-image-classification-model = module.sqs.eks_queue_arns["eks-image-classification-model"]
    eks-feature-extraction-model   = module.sqs.eks_queue_arns["eks-feature-extraction-model"]
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

  project_name = "${var.project_name}-serverless"
  env          = var.env
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnets

  database_name              = "imaige"
  lambda_security_group_id   = module.lambda_processors.all_security_group_ids[0]
  engine_version             = "16.6"
  publicly_accessible        = true
  eks_node_security_group_id = module.eks.node_security_group_id

  instance_count = 1   # Single instance for dev
  min_capacity   = 1   # Start lower for dev
  max_capacity   = 256 # Much lower ceiling for dev

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

# This is just the updated part of your modules.tf file

module "eks_processors" {
  source = "./../../modules/eks_processors"

  project_name = var.project_name
  env          = var.env
  aws_region   = data.aws_region.current.name

  # Shared services configuration
  shared_account_id = data.terraform_remote_state.shared.outputs.account_id
  shared_role_arn   = data.terraform_remote_state.shared.outputs.cross_account_role_arn

  # Disable shared role assumption temporarily until we resolve the errors
  enable_shared_role_assumption = false

  # Aurora configurations
  aurora_cluster_arn   = module.aurora.cluster_arn
  aurora_secret_arn    = module.aurora.secret_arn
  aurora_database_name = module.aurora.database_name

  # Kubernetes namespace
  namespace = "default"

  # SQS configuration
  sqs_queues = {
    "feature-extraction-model"   = module.sqs.eks_queue_urls["eks-feature-extraction-model"]
    "image-classification-model" = module.sqs.eks_queue_urls["eks-image-classification-model"]
  }

  # Security and identity
  kms_key_arn       = module.security.kms_key_arn
  oidc_provider     = module.eks.oidc_provider
  oidc_provider_arn = module.eks.oidc_provider_arn

  # S3 bucket access
  s3_bucket_arns = [
    local.s3_helm_charts_bucket_arn,
    "${local.s3_helm_charts_bucket_arn}/*"
  ]

  # Set enable_helm_deployments to false for now while we set up the infrastructure
  enable_helm_deployments = true

  # Resource settings
  replicas = 1
  model_replicas = {
    "evidence-model"                 = 1
    "image-classification-model"     = 2
    "feature-extraction-model"       = 1
    "external-api"                   = 1
    "similarity-model"               = 1
    "similarity-set-sorting-service" = 1
    "personhood-model"               = 1
  }
  cpu_request    = "100m"
  memory_request = "128Mi"
  cpu_limit      = "500m"
  memory_limit   = "512Mi"

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
    local.s3_helm_charts_bucket_arn,
    "${local.s3_helm_charts_bucket_arn}/*"
  ]

  # Add KMS keys
  kms_key_arns = [
    data.terraform_remote_state.shared.outputs.kms_key_arn
  ]

  tags = var.tags
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  project_name   = var.project_name
  env            = var.env
  github_org     = var.github_org
  github_repo    = var.github_repo
  account_type   = "workload"
  aws_region     = data.aws_region.current.name
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
    local.s3_helm_charts_bucket_arn,
    "${local.s3_helm_charts_bucket_arn}/*"
  ]

  # Cross-account role to assume
  cross_account_roles = [
    data.terraform_remote_state.shared.outputs.cross_account_role_arn
  ]

  enable_cicd_permissions = true

  tags = var.tags
}

# Define locals for shared account resources
# locals {
#   #shared_account_id = data.terraform_remote_state.shared.outputs.account_id

#   # Convert shared ECR repository ARNs to a list
#   shared_ecr_repository_arns = [
#     for repo in var.shared_ecr_repositories : 
#     "arn:aws:ecr:${data.aws_region.current.name}:${local.shared_account_id}:repository/${var.project_name}-shared-${repo}"
#   ]
# }
