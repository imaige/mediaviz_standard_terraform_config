# Existing Infrastructure
module "vpc" {
  source = "./../../modules/networking"

  cluster_name = var.cluster_name
  env          = var.env
}

module "eks" {
  source = "./../../modules/eks"

  cluster_name    = var.cluster_name
  env             = var.env
  cluster_version = var.cluster_version

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  eks_primary_instance_type = var.eks_primary_instance_type
  node_group_min_size       = var.node_group_min_size
  node_group_max_size       = var.node_group_max_size
  node_group_desired_size   = var.node_group_desired_size

  aws_account_id     = var.aws_account_id
  kms_key_arn        = module.security.kms_key_arn
  kms_key_id         = module.security.kms_key_id
  eks_admin_role_arn = module.security.eks_admin_role_arn
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
  replica_kms_key_id   = module.security.kms_key_id
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

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  # ECR configurations 
  ecr_repository_url  = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-${var.env}"
  ecr_repository_arns = values(module.ecr.repository_arns)

  # SQS configurations - use the map of queue ARNs
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

module "security" {
  source = "./../../modules/security"

  project_name = var.project_name
  env          = var.env
  kms_key_arn  = module.security.kms_key_arn
  kms_key_id   = module.security.kms_key_id
  # eks_node_role_arn = module.eks.eks_managed_node_role_arn
  tags = var.tags
  cluster_name = module.eks.cluster_name

}

module "eks_functions" {
  source = "./../../modules/eks_functions"

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
  allowed_ips = [
    "24.5.226.154/32",
    "73.169.81.101/32",
    "67.241.163.178/32",
    "76.155.77.153/32",
    "136.29.106.130/32",
    "67.162.158.188/32",
    "136.36.145.192/32",
    "135.129.132.20/32"
  ]
  aurora_endpoint = module.aurora.cluster_endpoint
  tags            = var.tags
}

module "ecr" {
  source = "./../../modules/ecr"

  project_name = var.project_name
  env          = var.env
  kms_key_arn  = module.security.kms_key_arn

  cross_account_arns = [] # Add any cross-account ARNs if needed

  tags = var.tags
}

module "eks_processors" {
  source = "./../../modules/eks_processors"

  project_name = var.project_name
  env          = var.env
  aws_region   = var.aws_region

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

  tags = var.tags
}
