module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = "${var.cluster_name}-${var.env}-cluster"
  cluster_version = var.cluster_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids

  # Security configurations
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  enable_irsa                     = true

  # Authentication configuration
  authentication_mode = "API"

  access_entries = {
    # Admin access
    admin = {
      kubernetes_groups = ["cluster-admin"]
      principal_arn     = var.eks_admin_role_arn
      type              = "STANDARD"
    }
  }

  # cluster_encryption_config = {
  #   provider_key_arn = var.kms_key_arn
  #   resources        = ["secrets"]
  # }


  cluster_addons = {
    coredns = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  enable_cluster_creator_admin_permissions = true
  eks_managed_node_groups = {
    primary_node_group = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.eks_primary_instance_type

      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      # Enable detailed monitoring
      enable_monitoring = true

      # Enable EBS optimization
      ebs_optimized = true

      iam_role_additional_policies = {
        secrets_policy = aws_iam_policy.node_secrets_policy.arn
      }

      # Block device mappings
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            encrypted             = true
            kms_key_id            = var.kms_key_arn
            delete_on_termination = true
          }
        }
      }
    }

    gpu_node_group = {
      ami_type       = "AL2_x86_64_GPU"
      instance_types = ["g4dn.xlarge"] # GPU instance type

      min_size     = 2
      max_size     = 5
      desired_size = 2

      enable_monitoring = true
      ebs_optimized     = true

      iam_role_additional_policies = {
        secrets_policy = aws_iam_policy.node_secrets_policy.arn
      }

      labels = {
        "node.kubernetes.io/instance-type" = "g4dn.xlarge"
        "nvidia.com/gpu.present"           = "true"
        "nvidia.com/gpu.product"           = "Tesla-T4"
      }

      taints = {
        dedicated = {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            encrypted             = true
            kms_key_id            = var.kms_key_arn
            delete_on_termination = true
          }
        }
      }
    }
  }

  # Enable logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = {
    Environment = var.env
    Terraform   = "true"
  }
}

# Create CloudWatch log group for EKS logs
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${var.cluster_name}-${var.env}-cluster"
  retention_in_days = 365 # Changed from 30 to 365
  # kms_key_id       = var.kms_key_arn
}

resource "helm_release" "nvidia_device_plugin" {
  name             = "nvdp"
  repository       = "https://nvidia.github.io/k8s-device-plugin"
  chart            = "nvidia-device-plugin"
  version          = "0.17.0"
  namespace        = "nvidia-device-plugin"
  create_namespace = true

  set {
    name  = "gfd.enabled"
    value = "true"
    type  = "string"
  }

  set {
    name  = "migStrategy"
    value = "none"
  }

  set {
    name  = "failOnInitError"
    value = "true"
    type  = "string"
  }

  set {
    name  = "deviceListStrategy"
    value = "envvar"
  }

  set {
    name  = "deviceIDStrategy"
    value = "uuid"
  }

  set {
    name  = "nfd.enabled"
    value = "true"
    type  = "string"
  }
}

resource "kubernetes_namespace" "gpu_resources" {
  metadata {
    name = "gpu-resources"
  }
}

resource "aws_iam_policy" "node_secrets_policy" {
  name        = "mediaviz-dev-node-secrets-access"
  description = "Policy allowing EKS nodes to access all secrets, KMS, and SQS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement",
          "rds-data:BeginTransaction",
          "rds-data:CommitTransaction",
          "rds-data:RollbackTransaction"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:ReEncrypt*"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:*"  # Full SQS access
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutBucketPublicAccessBlock"
        ]
        Resource = ["*"]
      }
    ]
  })
}