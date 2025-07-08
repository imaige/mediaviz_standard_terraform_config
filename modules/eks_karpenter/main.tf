module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  create_cloudwatch_log_group = false

  cluster_name             = "${var.project_name}-${var.env}-karpenter"
  cluster_version          = var.karpenter_cluster_version
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
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
      configuration_values = jsonencode({
        computeType = "Fargate"
      })
    }
    eks-pod-identity-agent = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
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
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = aws_iam_role.ebs_csi_role.arn
    }
  }

  enable_cluster_creator_admin_permissions = true

  # Define node groups with appropriate configurations
  eks_managed_node_groups = {}

  # Enable logging for audit and troubleshooting
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Fargate profile for system workloads (optional)
  fargate_profiles = {
    system = {
      name                   = "system"
      pod_execution_role_arn = aws_iam_role.fargate_pod_execution_role.arn
      selectors = [
        {
          namespace = "kube-system"
        },
        {
          namespace = "monitoring"
        }
      ]
      tags = {
        Environment = var.env
        Terraform   = "true"
      }
    },
    karpenter = {
      name                   = "karpenter"
      pod_execution_role_arn = aws_iam_role.fargate_pod_execution_role.arn
      selectors = [
        {
          namespace = "karpenter"
        }
      ]
      tags = {
        Environment = var.env
        Terraform   = "true"
      }
    }
  }

  # Module tags
  tags = merge(var.tags, {
    Environment = var.env
    ManagedBy   = "terraform"
    Project     = var.project_name
  })

}

module "karpenter" {

  depends_on = [
    module.eks
  ]

  source  = "terraform-aws-modules/eks/aws//modules/karpenter" # Note the "//modules/karpenter"
  version = "~> 20.31"

  cluster_name = module.eks.cluster_name

  irsa_oidc_provider_arn = module.eks.oidc_provider_arn

  irsa_namespace_service_accounts = ["karpenter:karpenter"]
  create_instance_profile         = true
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  enable_spot_termination = true
}

resource "helm_release" "karpenter" {

  depends_on = [
    module.karpenter
  ]

  namespace        = "karpenter"
  create_namespace = true
  name             = "karpenter"
  # This chart is v1.5.1
  chart   = "${path.module}/chart/karpenter"
  wait    = true
  timeout = "900"

  # Values passed to the Helm chart
  set {
    # Link the kubernetes service account to the IAM role
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.iam_role_arn # Value from the module output
  }

  set {
    # The cluster being managed
    name  = "settings.clusterName"
    value = module.eks.cluster_name # Value from the EKS module output
  }

  set {
    # Native Spot instance interrupt handling
    name  = "settings.interruptionQueue"
    value = module.karpenter.queue_name
  }
}

# Karpenter NodePool and EC2NodeClasses to replace the EKS managed nodegroups
# These are kubernetes custom resources

/*resource "kubernetes_manifest" "karpenter_primary_ec2nodeclass" {
  # Depends on the Karpenter Helm release being deployed

  depends_on = [
    helm_release.karpenter
  ]

  manifest = {
    "apiVersion" = "karpenter.k8s.aws/v1beta1"
    "kind"       = "EC2NodeClass"
    "metadata" = {
      "name"      = "karpenter-primary-node-class"
      "namespace" = var.namespace
      "annotations" = {
        "kubernetes.io/description" = "Primary node group for general workloads"
      }
    }

    "spec" = {
      "amiFamily" = "AL2023"
      "role"      = module.karpenter.node_iam_role_arn

      # Security groups and Subnets are discovered via tags.
      "securityGroupSelector" = {
        "karpenter.sh/discovery" = module.eks.cluster_name
      }
      "subnetSelector" = {
        "karpenter.sh/discovery" = module.eks.cluster_name
      }

      # EBS Block device
      "blockDeviceMappings" = {
        "deviceName" = "/dev/xvda"
        "ebs" = {
          "volumeSize"          = "100Gi"
          "volumeType"          = "gp3"
          "iops"                = 3000
          "throughput"          = 125
          "encrypted"           = true
          "kmsKeyId"            = var.kms_key_arn
          "deleteOnTermination" = true
        }
      }

      # Tags to apply to the individual ec2 instances
      "tags" = {
        "Name"                  = "${var.project_name}-${var.env}-primary-node"
        "NodeGroup"             = "primary"
        "WorkloadType"          = "general"
        "GpuType"               = "none"
        "Environment"           = "${var.env}"
        "ManagedBy"             = "karpenter"
        "karpenter.sh/nodepool" = "primary"
      }
    }
  }
}

# NodePools define the Kubernetes-level requirements for the nodes
resource "kubernetes_manifest" "karpenter_primary_nodepool" {
  depends_on = [
    helm_release.karpenter
  ]

  manifest = {
    "apiVersion" = "karpenter.k8s.aws/v1beta1"
    "kind"       = "NodePool"
    "metadata" = {
      "name" = "karpenter-primary-nodepool"
    }
    "spec" = {
      "disruption" = {
        "consolidationPolicy" = "WhenEmpty"
        "expireAfter"         = "720h"
      }
      "limits" = {
        "cpu"    = var.primary_nodepool_max_cpu
        "memory" = var.primary_nodepool_max_mem
      }
      "template" = {
        "spec" = {
          "labels" = {
            "karpenter.sh/nodepool"  = "primary"
            "node-type"              = "primary"
            "nvidia.com/gpu.present" = "false"
          }
          "nodeClassRef" = {
            "apiVersion" = "karpenter.k8s.aws/v1beta1"
            "kind"       = "EC2NodeClass"
            "name"       = "karpenter-primary-node-class"
          }
          "requirements" = [
            {
              "key"      = "karpenter.k8s.aws/instance-type"
              "operator" = "In"
              "values"   = var.eks_primary_instance_type
            },
            {
              "key"      = "kubernetes.io/arch"
              "operator" = "In"
              "values" = [
                "amd64",
              ]
            },
            {
              "key"      = "kubernetes.io/os"
              "operator" = "In"
              "values" = [
                "linux",
              ]
            },
            {
              "key"      = "karpenter.k8s.aws/capacity-type"
              "operator" = "In"
              "values"   = var.primary_nodepool_capacity_type
            },
          ]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "karpenter_high_power_gpu_ec2nodeclass" {
  # Depends on the Karpenter Helm release being deployed

  depends_on = [
    helm_release.karpenter
  ]

  manifest = {
    "apiVersion" = "karpenter.k8s.aws/v1beta1"
    "kind"       = "EC2NodeClass"
    "metadata" = {
      "name"      = "karpenter-high-power-gpu-node-class"
      "namespace" = var.namespace
      "annotations" = {
        "kubernetes.io/description" = "Karpenter-managed EC2NodeClass for high-power GPU"
      }
    }

    "spec" = {
      # For AL2023_x86_64_NVIDIA, the amiFamily is "AL2023".
      "amiFamily" = "AL2023"
      "role"      = module.karpenter.node_iam_role_arn

      # Security groups and Subnets are discovered via tags.
      "securityGroupSelector" = {
        "karpenter.sh/discovery" = module.eks.cluster_name
      }
      "subnetSelector" = {
        "karpenter.sh/discovery" = module.eks.cluster_name
      }

      # EBS Block device
      "blockDeviceMappings" = {
        "deviceName" = "/dev/xvda"
        "ebs" = {
          "volumeSize"          = "1000Gi"
          "volumeType"          = "gp3"
          "iops"                = 16000
          "throughput"          = 1000
          "encrypted"           = true
          "kmsKeyId"            = var.kms_key_arn
          "deleteOnTermination" = true
        }
      }

      # Tags to apply to the individual ec2 instances
      "tags" = {
        "Name"                  = "${var.project_name}-${var.env}-high-power-gpu-node"
        "NodeGroup"             = "high-power-gpu"
        "WorkloadType"          = "evidence-model"
        "GpuType"               = "nvidia-a10g"
        "Environment"           = var.env
        "ManagedBy"             = "karpenter"
        "karpenter.sh/nodepool" = "high-power-gpu"
      }
    }
  }
}

# NodePools define the Kubernetes-level requirements for the nodes
resource "kubernetes_manifest" "karpenter_high_power_gpu_nodepool" {

  depends_on = [
    helm_release.karpenter
  ]
  manifest = {
    "apiVersion" = "karpenter.k8s.aws/v1beta1"
    "kind"       = "NodePool"
    "metadata" = {
      "name" = "karpenter-high-power-gpu-nodepool"
    }
    "spec" = {
      "disruption" = {
        "consolidationPolicy" = "WhenEmpty"
        "expireAfter"         = "720h"
      }
      "limits" = {
        "cpu"    = var.evidence_gpu_nodepool_max_cpu
        "memory" = var.evidence_gpu_nodepool_max_mem
      }
      "template" = {
        "spec" = {
          "labels" = {
            "karpenter.sh/nodepool"  = "high-power-gpu-nodepool"
            "node-type"              = "high-power-gpu"
            "nvidia.com/gpu.present" = "true"
            "nvidia.com/gpu.product" = "A10G"
          }
          "nodeClassRef" = {
            "apiVersion" = "karpenter.k8s.aws/v1beta1"
            "kind"       = "EC2NodeClass"
            "name"       = "karpenter-high-power-gpu-node-class"
          }
          "requirements" = [
            {
              "key"      = "karpenter.k8s.aws/instance-type"
              "operator" = "In"
              "values"   = var.evidence_gpu_instance_types
            },
            {
              "key"      = "kubernetes.io/arch"
              "operator" = "In"
              "values" = [
                "amd64",
              ]
            },
            {
              "key"      = "kubernetes.io/os"
              "operator" = "In"
              "values" = [
                "linux",
              ]
            },
            {
              "key"      = "karpenter.k8s.aws/capacity-type"
              "operator" = "In"
              "values"   = var.evidence_gpu_nodepool_capacity_type
            },
          ]
          "taints" = [
            {
              "effect" = "NoSchedule"
              "key"    = "nvidia.com/gpu"
              "value"  = "true"
            },
          ]
        }
      }
    }
  }
}*/


/*
module "helm_release" "keda" {
  namespace        = "keda"
  create_namespace = true
  name             = "keda"
  # This chart is v2.17.2
  chart = "${path.module}/chart/keda"
  wait  = true

  set {
    # The cluster name
    name  = "ClusterName"
    value = module.eks.cluster_name
  }

  set {
    # Enable IRSA
    name  = "podIdentity.aws.irsa.enabled"
    value = true
  }
  set {
    # IRSA RoleArn
    name  = "podIdentity.aws.irsa.roleArn"
    value = module.eks.oidc_provider_arn
  }
  set {
    # logging
    name  = "logging.operator.format"
    value = "json"
  }
}
*/

# Role for EBS CSI driver with IRSA
resource "aws_iam_role" "ebs_csi_role" {
  name = "${var.project_name}-${var.env}-karpenter-ebs-csi-role"

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

# Create CloudWatch log group for Karpenter EKS logs
resource "aws_cloudwatch_log_group" "eks_logs_karpenter" {
  name              = "/aws/eks/${var.project_name}-${var.env}-karpenter-cluster/cluster"
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

  name             = "nvdp"
  repository       = "https://nvidia.github.io/k8s-device-plugin"
  chart            = "nvidia-device-plugin"
  version          = var.nvidia_plugin_version
  namespace        = "nvidia-device-plugin"
  create_namespace = true

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
  name        = var.node_secrets_policy_metadata["name"]
  description = var.node_secrets_policy_metadata["description"]

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
    name      = "${var.project_name}-karpenter-shared-access"
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
  name        = "${var.project_name}-${var.env}-karpenter-node-basic-policy"
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
