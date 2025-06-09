module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  create_cloudwatch_log_group = false

  cluster_name    = "${var.project_name}-${var.env}-cluster"
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

  access_entries = merge(
    {
      # Admin access
      admin = {
        kubernetes_groups = ["cluster-admin"]
        principal_arn     = var.eks_admin_role_arn
        type              = "STANDARD"
      }
    },
    var.github_actions_role_arn != "" ? {
      # CI/CD access for deployments
      cicd = {
        kubernetes_groups = ["system:masters"]
        principal_arn     = var.github_actions_role_arn
        type              = "STANDARD"
      }
    } : {},
    var.additional_access_entries # Add this line to include the additional entries
  )


  # Enable encryption for Kubernetes secrets
  cluster_encryption_config = {
    provider_key_arn = var.kms_key_arn
    resources        = ["secrets"]
  }

  # Cluster addons with automatic updates
  cluster_addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        computeType = "Fargate"
      })
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_ENI_TARGET          = "2"
          MINIMUM_IP_TARGET        = "10"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = aws_iam_role.ebs_csi_role.arn
    }
  }

  enable_cluster_creator_admin_permissions = true

  # Define node groups with appropriate configurations
  eks_managed_node_groups = {
    # Primary node group for general workloads
    primary = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.eks_primary_instance_type
      capacity_type  = "SPOT"

      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      # Enable detailed monitoring
      enable_monitoring = true

      # Enable EBS optimization
      ebs_optimized = true

      # Add IAM policies
      iam_role_additional_policies = {
        secrets_policy = aws_iam_policy.node_secrets_policy.arn,
        ssm_policy     = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      # Block device mappings for root volume
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            kms_key_id            = var.kms_key_arn
            delete_on_termination = true
          }
        }
      }

      # Kubernetes labels for node selection
      labels = {
        "node-type"                        = "primary"
        "node.kubernetes.io/workload-type" = "general"
      }

      # Comprehensive tagging
      tags = merge(var.tags, {
        Name        = "${var.project_name}-${var.env}-primary-node"
        NodeGroup   = "primary"
        Environment = var.env
        ManagedBy   = "terraform"
      })
    }

    # GPU node group for ML workloads
    gpu = {
      ami_type       = "AL2023_x86_64_NVIDIA"
      instance_types = var.gpu_instance_types
      capacity_type  = "SPOT"

      min_size     = var.gpu_node_min_size
      max_size     = var.gpu_node_max_size
      desired_size = var.gpu_node_desired_size

      enable_monitoring = true
      ebs_optimized     = true

      # Configure update behavior
      update_config = {
        max_unavailable_percentage = 25
      }

      # Add IAM policies
      iam_role_additional_policies = {
        secrets_policy = aws_iam_policy.node_secrets_policy.arn,
        ssm_policy     = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      # Kubernetes labels for node selection
      labels = {
        "nvidia.com/gpu.present"           = "true"
        "nvidia.com/gpu.product"           = "Tesla-T4"
        "node-type"                        = "gpu"
        "app-type"                         = "ml-application"
      }

      # Taints to ensure only GPU workloads run on these nodes
      taints = {
        dedicated = {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      # Block device mappings with larger volume for ML workloads
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 200
            volume_type           = "gp3"
            iops                  = 4000
            throughput            = 200
            encrypted             = true
            kms_key_id            = var.kms_key_arn
            delete_on_termination = true
          }
        }
      }

      # Comprehensive tagging
      tags = merge(var.tags, {
        Name        = "${var.project_name}-${var.env}-gpu-node"
        NodeGroup   = "gpu"
        GpuType     = "nvidia-t4"
        Environment = var.env
        ManagedBy   = "terraform"
      })
    }

    # High-performance GPU node group dedicated for evidence model
    "high_power_gpu-${var.nodegroup_version}" = {
      ami_type       = "AL2023_x86_64_NVIDIA"
      instance_types = var.evidence_gpu_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.evidence_gpu_node_min_size
      max_size     = var.evidence_gpu_node_max_size
      desired_size = var.evidence_gpu_node_desired_size

      enable_monitoring = true
      ebs_optimized     = true

      # Configure update behavior
      update_config = {
        max_unavailable_percentage = 25
      }

      # Add IAM policies
      iam_role_additional_policies = {
        secrets_policy = aws_iam_policy.node_secrets_policy.arn,
        ssm_policy     = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      # Kubernetes labels for node selection
      labels = {
        "nvidia.com/gpu.present"           = "true"
        "nvidia.com/gpu.product"           = "A10G"
        "node-type"                        = "high-power-gpu"
      }

      taints = {
        dedicated = {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      # High-performance block device mappings for evidence processing
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 1000
            volume_type           = "gp3"
            iops                  = 16000
            throughput            = 1000
            encrypted             = true
            kms_key_id            = var.kms_key_arn
            delete_on_termination = true
          }
        }
      }

      # Comprehensive tagging
      tags = merge(var.tags, {
        Name         = "${var.project_name}-${var.env}-high-power-gpu-node"
        NodeGroup    = "high-power-gpu"
        WorkloadType = "evidence-model"
        GpuType      = "nvidia-a10g"
        Environment  = var.env
        ManagedBy    = "terraform"
      })
    }
  }

  # Enable logging for audit and troubleshooting
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Fargate profile for system workloads (optional)
  fargate_profiles = var.enable_fargate ? {
    system = {
      name = "system"
      selectors = [
        {
          namespace = "kube-system"
          labels = {
            k8s-app = "kube-dns"
          }
        },
        {
          namespace = "monitoring"
        }
      ]
      tags = {
        Environment = var.env
        Terraform   = "true"
      }
    }
  } : {}

  # Module tags
  tags = merge(var.tags, {
    Environment = var.env
    ManagedBy   = "terraform"
    Project     = var.project_name
  })
}

# Role for EBS CSI driver with IRSA
resource "aws_iam_role" "ebs_csi_role" {
  name = "${var.project_name}-${var.env}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = "arn:aws:iam::${var.aws_account_id}:oidc-provider/${module.eks.oidc_provider}"
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${module.eks.oidc_provider}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })

  tags = var.tags
}

# Attach the required policy for EBS CSI driver
resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = aws_iam_role.ebs_csi_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Create CloudWatch log group for EKS logs
resource "aws_cloudwatch_log_group" "eks_logs" {
  name              = "/aws/eks/${var.project_name}-${var.env}-cluster/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.cloudwatch_logs_kms_key_arn

  tags = merge(var.tags, {
    Environment = var.env
    ManagedBy   = "terraform"
  })
}

# Install NVIDIA Device Plugin for GPU support
resource "helm_release" "nvidia_device_plugin" {
  count = var.install_nvidia_plugin && var.create_kubernetes_resources ? 1 : 0

  name       = "nvdp"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  version    = var.nvidia_plugin_version
  namespace  = "kube-system"

  values = [
    yamlencode({
      gfd = {
        enabled = "true" # Changed from boolean to string
      },
      migStrategy        = "none",
      failOnInitError    = "true", # Changed from boolean to string
      deviceListStrategy = "envvar",
      deviceIDStrategy   = "uuid",
      nfd = {
        enabled = "true" # Changed from boolean to string
      }
    })
  ]

  depends_on = [module.eks]
}

# Node IAM policy with least privilege
resource "aws_iam_policy" "node_secrets_policy" {
  name        = "${var.project_name}-${var.env}-node-access-policy"
  description = "Policy allowing EKS nodes to access required resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Secrets Manager access
      [{
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${var.project_name}-${var.env}*"
        ]
      }],

      # Aurora Data API access - only include if aurora_cluster_arns is not empty
      length(var.aurora_cluster_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement",
          "rds-data:BeginTransaction",
          "rds-data:CommitTransaction",
          "rds-data:RollbackTransaction"
        ]
        Resource = var.aurora_cluster_arns
      }] : [],

      # KMS access - only include if kms_key_arns is not empty
      length(var.kms_key_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey*"
        ]
        Resource = var.kms_key_arns
      }] : [],

      # SQS access - only include if sqs_queue_arns is not empty
      length(var.sqs_queue_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = var.sqs_queue_arns
      }] : [],

      # S3 access - only include if s3_bucket_arns is not empty
      length(var.s3_bucket_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Resource = concat(
          var.s3_bucket_arns,
          [for arn in var.s3_bucket_arns : "${arn}/*"]
        )
      }] : []
    )
  })

  tags = var.tags
}

# Create service account for cross-account access if needed
resource "kubernetes_service_account" "shared_resources_sa" {
  count = var.enable_shared_access && var.create_kubernetes_resources ? 1 : 0

  metadata {
    name      = "${var.project_name}-shared-access"
    namespace = "default"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.shared_access_role_arn
    }
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "aws_iam_policy" "node_basic_policy" {
  name        = "${var.project_name}-${var.env}-node-basic-policy"
  description = "Basic policy for EKS nodes when no specific resources are defined"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = ["*"]
      }
    ]
  })
}