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

  aws_account_id = var.aws_account_id
  kms_key_arn    = module.security.kms_key_arn
  kms_key_id     = module.security.kms_key_id
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

module "lambda" {
  source = "./../../modules/lambda"

  project_name                = var.project_name
  env                         = var.env
  s3_bucket_name              = module.s3.bucket_id
  s3_bucket_arn               = module.s3.bucket_arn
  tags                        = var.tags
  signing_profile_version_arn = module.security.signing_profile_arn
  subnet_ids                  = module.vpc.private_subnets
  vpc_id                      = module.vpc.vpc_id
  kms_key_arn                 = module.security.kms_key_arn
  kms_key_id                  = module.security.kms_key_id
  # encrypted_env_var           = var.encrypted_env_var
  sqs_queue_arn  = module.sqs.queue_arn
  output_bucket_name = module.s3.processed_bucket_id
  output_bucket_arn  = module.s3.processed_bucket_arn
}

module "api_gateway" {
  source = "./../../modules/api_gateway"

  project_name         = var.project_name
  env                  = var.env
  lambda_invoke_arn    = module.lambda.invoke_arn
  lambda_function_name = module.lambda.function_name
  kms_key_arn          = module.security.kms_key_arn
  kms_key_id           = module.security.kms_key_id
  waf_acl_arn           = module.security.waf_acl_arn
}

module "eventbridge" {
  source = "./../../modules/eventbridge"

  project_name = var.project_name
  env          = var.env
  target_arn   = module.sqs.queue_arn
  kms_key_arn  = module.security.kms_key_arn
  kms_key_id   = module.security.kms_key_id
  aws_sqs_queue_dlq_arn = module.sqs.dlq_arn
}

module "sqs" {
  source = "./../../modules/sqs"

  project_name         = var.project_name
  env                  = var.env
  eventbridge_rule_arn = module.eventbridge.rule_arn
  tags                 = var.tags
  kms_key_arn          = module.security.kms_key_arn
  kms_key_id           = module.security.kms_key_id
}

module "security" {
  source = "./../../modules/security"

  project_name = var.project_name
  env          = var.env
  kms_key_arn  = module.security.kms_key_arn
  kms_key_id   = module.security.kms_key_id
}
