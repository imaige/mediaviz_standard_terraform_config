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

  cluster_tags = {
    "karpenter.sh/discovery" = "${var.project_name}-${var.env}-karpenter"
  }

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
    karpenter = {
      name = "karpenter"
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

locals {
  # Filtered map for models that need Helm deployments
  helm_models = {
    for k, v in var.models : k => v if v.needs_helm
  }

  # Each time we add a KEDA scaler, we need to update this map
  keda_scalers = {
    time_scalers = {
      for k, v in var.models : k => v.keda_scalers.time_scaler if can(v.keda_scalers.time_scaler)
    }
  }

  similarity_set_sorting_service_url = data.kubernetes_secret.secrets.data["SIMILARITY_SORTING_SERVICE_URL"]
}

resource "aws_iam_role" "fargate_pod_execution_role" {
  name = "${var.project_name}-${var.env}-karpenter-fargate-pod-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks-fargate-pods.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fargate_pod_execution_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate_pod_execution_role.name
}


module "karpenter" {

  depends_on = [
    module.eks
  ]

  source  = "terraform-aws-modules/eks/aws//modules/karpenter" # Note the "//modules/karpenter"
  version = "~> 20.31"

  cluster_name = module.eks.cluster_name

  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  enable_v1_permissions           = true
  irsa_namespace_service_accounts = ["karpenter:karpenter"]
  enable_irsa                     = true
  create_iam_role                 = true
  create_instance_profile         = true
  create_node_iam_role            = true
  enable_spot_termination         = true
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
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

  set {
    name  = "controller.tolerations[1].key"
    value = "eks.amazonaws.com/compute-type"
  }
  set {
    name  = "controller.tolerations[1].operator"
    value = "Equal"
  }
  set {
    name  = "controller.tolerations[1].value"
    value = "fargate"
  }
  set {
    name  = "controller.tolerations[1].effect"
    value = "NoSchedule"
  }

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

resource "kubernetes_manifest" "karpenter_primary_ec2nodeclass" {
  # Depends on the Karpenter Helm release being deployed
  manifest = {
    "apiVersion" = "karpenter.k8s.aws/v1"
    "kind"       = "EC2NodeClass"
    "metadata" = {
      "name" = "karpenter-primary-node-class"
      "annotations" = {
        "kubernetes.io/description" = "Karpenter-managed EC2NodeClass for generic workloads"
      }
    }

    spec = {
      # For AL2023_x86_64_NVIDIA, the amiFamily is "AL2023".
      amiFamily = "AL2023"

      amiSelectorTerms = [{
        name = "${var.primary_ami_selector}*"
      }]

      role = module.karpenter.node_iam_role_arn

      # Security groups and Subnets are discovered via tags.
      "securityGroupSelectorTerms" = [{
        tags = {
          "karpenter.sh/discovery" = module.eks.cluster_name
        }
      }]
      "subnetSelectorTerms" = [{
        tags = {
          "karpenter.sh/discovery" = module.eks.cluster_name
        }
      }]

      # EBS Block device
      "blockDeviceMappings" = [{
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
      }]

      # Tags to apply to the individual ec2 instances
      "tags" = {
        "Name"         = "${var.project_name}-${var.env}-karpenter-primary-node"
        "NodeGroup"    = "primary"
        "WorkloadType" = "general"
        "Environment"  = var.env
        "ManagedBy"    = "karpenter"
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
    "apiVersion" = "karpenter.sh/v1"
    "kind"       = "NodePool"
    "metadata" = {
      "name" = "karpenter-primary-nodepool"
    }
    "spec" = {
      "limits" = {
        "cpu"    = var.primary_nodepool_max_cpu
        "memory" = var.primary_nodepool_max_mem
      }
      "disruption" = {
        "consolidationPolicy" = "WhenEmpty"
        "consolidateAfter"    = "30s"
      }
      "template" = {
        "metadata" = {
          "labels" = {
            "karpenter-managed" = "true"
            "workload-type"     = "primary"
          }
        }
        "spec" = {
          "expireAfter" = "72h"
          "nodeClassRef" = {
            "group" = "karpenter.k8s.aws"
            "kind"  = "EC2NodeClass"
            "name"  = "karpenter-primary-node-class"
          }
          "requirements" = [
            {
              "key"      = "workload-type"
              "operator" = "In"
              "values"   = ["primary"]
            },
            {
              "key"      = "node.kubernetes.io/instance-type"
              "operator" = "In"
              "values"   = var.primary_nodepool_instance_types
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
              "key"      = "karpenter.sh/capacity-type"
              "operator" = "In"
              "values"   = var.primary_nodepool_capacity_type
            }
          ]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "karpenter_high_power_gpu_ec2nodeclass" {
  # Depends on the Karpenter Helm release being deployed
  manifest = {
    "apiVersion" = "karpenter.k8s.aws/v1"
    "kind"       = "EC2NodeClass"
    "metadata" = {
      "name" = "karpenter-high-power-gpu-node-class"
      "annotations" = {
        "kubernetes.io/description" = "Karpenter-managed EC2NodeClass for high-power GPU workloads"
      }
    }

    spec = {
      # For AL2023_x86_64_NVIDIA, the amiFamily is "AL2023".
      amiFamily = "AL2023"

      amiSelectorTerms = [{
        name = "${var.evidence_gpu_ami_selector}*"
      }]

      role = module.karpenter.node_iam_role_arn

      # Security groups and Subnets are discovered via tags.
      "securityGroupSelectorTerms" = [{
        tags = {
          "karpenter.sh/discovery" = module.eks.cluster_name
        }
      }]
      "subnetSelectorTerms" = [{
        tags = {
          "karpenter.sh/discovery" = module.eks.cluster_name
        }
      }]

      # EBS Block device
      "blockDeviceMappings" = [{
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
      }]

      # Tags to apply to the individual ec2 instances
      "tags" = {
        "Name"         = "${var.project_name}-${var.env}-karpenter-high-power-gpu-node"
        "NodeGroup"    = "high-power-gpu"
        "WorkloadType" = "evidence-model"
        "GpuType"      = "nvidia-a10g"
        "Environment"  = var.env
        "ManagedBy"    = "karpenter"
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
    "apiVersion" = "karpenter.sh/v1"
    "kind"       = "NodePool"
    "metadata" = {
      "name" = "karpenter-high-power-gpu-nodepool"
    }
    "spec" = {
      "limits" = {
        "cpu"    = var.evidence_gpu_nodepool_max_cpu
        "memory" = var.evidence_gpu_nodepool_max_mem
      }
      "disruption" = {
        "consolidationPolicy" = "WhenEmpty"
        "consolidateAfter"    = "30s"
      }
      "template" = {
        "metadata" = {
          "labels" = {
            "karpenter-managed" = "true"
          }
        }
        "spec" = {
          "expireAfter" = "72h"
          "nodeClassRef" = {
            "group" = "karpenter.k8s.aws"
            "kind"  = "EC2NodeClass"
            "name"  = "karpenter-high-power-gpu-node-class"
          }
          "taints" = [
            {
              "key"    = "nvidia.com/gpu"
              "value"  = "true"
              "effect" = "NoSchedule"
            }
          ]
          "requirements" = [
            {
              "key"      = "workload-type"
              "operator" = "In"
              "values"   = ["high-power"]
            },
            {
              "key"      = "node.kubernetes.io/instance-type"
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
              "key"      = "karpenter.sh/capacity-type"
              "operator" = "In"
              "values"   = var.evidence_gpu_nodepool_capacity_type
            },
            {
              "key"      = "nvidia.com/gpu.present"
              "operator" = "In"
              "values"   = ["true"]
            },
          ]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "karpenter_gpu_ec2nodeclass" {
  # Depends on the Karpenter Helm release being deployed
  manifest = {
    "apiVersion" = "karpenter.k8s.aws/v1"
    "kind"       = "EC2NodeClass"
    "metadata" = {
      "name" = "karpenter-gpu-node-class"
      "annotations" = {
        "kubernetes.io/description" = "Karpenter-managed EC2NodeClass for GPU workloads"
      }
    }

    spec = {
      # For AL2023_x86_64_NVIDIA, the amiFamily is "AL2023".
      amiFamily = "AL2023"

      amiSelectorTerms = [{
        name = "${var.gpu_ami_selector}*"
      }]

      role = module.karpenter.node_iam_role_arn

      # Security groups and Subnets are discovered via tags.
      "securityGroupSelectorTerms" = [{
        tags = {
          "karpenter.sh/discovery" = module.eks.cluster_name
        }
      }]
      "subnetSelectorTerms" = [{
        tags = {
          "karpenter.sh/discovery" = module.eks.cluster_name
        }
      }]

      # EBS Block device
      "blockDeviceMappings" = [{
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
      }]

      # Tags to apply to the individual ec2 instances
      "tags" = {
        "Name"         = "${var.project_name}-${var.env}-karpenter-gpu-node"
        "NodeGroup"    = "gpu"
        "WorkloadType" = "gpu"
        "Environment"  = var.env
        "ManagedBy"    = "karpenter"
      }
    }
  }
}


# NodePools define the Kubernetes-level requirements for the nodes
resource "kubernetes_manifest" "karpenter_gpu_nodepool" {

  depends_on = [
    helm_release.karpenter
  ]
  manifest = {
    "apiVersion" = "karpenter.sh/v1"
    "kind"       = "NodePool"
    "metadata" = {
      "name" = "karpenter-gpu-nodepool"
    }
    "spec" = {
      "limits" = {
        "cpu"    = var.gpu_nodepool_max_cpu
        "memory" = var.gpu_nodepool_max_mem
      }
      "disruption" = {
        "consolidationPolicy" = "WhenEmpty",
        "consolidateAfter"    = "30s"
      }
      "template" = {
        "metadata" = {
          "labels" = {
            "karpenter-managed" = "true"
          }
        }
        "spec" = {
          "expireAfter" = "72h"
          "nodeClassRef" = {
            "group" = "karpenter.k8s.aws"
            "kind"  = "EC2NodeClass"
            "name"  = "karpenter-gpu-node-class"
          }
          "taints" = [
            {
              "key"    = "nvidia.com/gpu"
              "value"  = "true"
              "effect" = "NoSchedule"
            }
          ]
          "requirements" = [
            {
              "key"      = "workload-type"
              "operator" = "In"
              "values"   = ["gpu"]
            },
            {
              "key"      = "node.kubernetes.io/instance-type"
              "operator" = "In"
              "values"   = var.gpu_nodepool_instance_types
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
              "key"      = "karpenter.sh/capacity-type"
              "operator" = "In"
              "values"   = var.gpu_nodepool_capacity_type
            },
            {
              "key"      = "nvidia.com/gpu.present"
              "operator" = "In"
              "values"   = ["true"]
            },
          ]
        }
      }
    }
  }
}


resource "helm_release" "keda" {
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

resource "kubernetes_manifest" "time_scaler" {
  for_each = local.keda_scalers.time_scalers

  depends_on = [
    helm_release.keda
  ]

  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "ScaledObject"

    metadata = {
      name      = "${each.key}-time-scaler"
      namespace = "default"
    }

    spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1"
        kind       = "Deployment"
        name       = "${helm_release.model_deployments[each.key].name}-karpenter"
      }

      # Min/Max pod replicas
      minReplicaCount = lookup(each.value, "minReplicas", 1)
      maxReplicaCount = lookup(each.value, "maxReplicas", 5)
      pollingInterval = lookup(each.value, "pollingInterval", 30)

      # Scaling triggers
      triggers = [
        {
          type = "cron"
          metadata = {
            timezone = lookup(each.value, "timezone", "America/Los_Angeles")

            start = lookup(each.value, "start", "0 8 * * 1-5")
            end   = lookup(each.value, "end", "0 18 * * 1-5")

            desiredReplicas = tostring(lookup(each.value, "desiredReplicas", 2))
          }
        },
      ]
      fallback = {
        failureThreshold = lookup(each.value, "failureThreshold", 3)
        replicas         = lookup(each.value, "fallbackReplicas", 2)
      }
    }
  }
}

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
  count = var.install_nvidia_plugin ? 1 : 0

  name             = "nvidia-device-plugin"
  repository       = "https://nvidia.github.io/k8s-device-plugin"
  chart            = "nvidia-device-plugin"
  version          = var.nvidia_plugin_version
  namespace        = "kube-system"
  create_namespace = false

  values = [
    yamlencode({
      gfd = {
        enabled = true
      },
      migStrategy        = "none",
      failOnInitError    = true,
      deviceListStrategy = "envvar",
      deviceIDStrategy   = "uuid",
      nfd = {
        enabled = true
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
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-${var.env}*",
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:mediaviz-k8s-secrets",
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-serverless-${var.env}-aurora-credentials-pg*",
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

      # Generic KMS access that we should tighten up later
      length(var.kms_key_access) > 0 ? [{
        Effect = "Allow"
        Action = [
          "kms:*"
        ]
        Resource = "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
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
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = var.shared_access_role_arn
    }
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "aws_iam_policy" "node_sqs_policy" {
  name        = "${var.project_name}-${var.env}-karpenter-node-sqs-policy"
  description = "Policy for Fargate EKS nodes to access SQS queues"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = var.sqs_queue_arns
      }
    ]
  })
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

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "fargate_sa_role" {
  name = "${var.project_name}-${var.env}-fargate-sa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${module.eks.oidc_provider}"
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${module.eks.oidc_provider}:sub" : "system:serviceaccount:default:${var.project_name}-${var.env}-fargate-sa",
          "${module.eks.oidc_provider}:aud" : "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

# Attach the existing policies to the new role
resource "aws_iam_role_policy_attachment" "fargate_sa_node_basic_policy_attachment" {
  role       = aws_iam_role.fargate_sa_role.name
  policy_arn = aws_iam_policy.node_basic_policy.arn
}

resource "aws_iam_role_policy_attachment" "fargate_sa_node_secrets_policy_attachment" {
  role       = aws_iam_role.fargate_sa_role.name
  policy_arn = aws_iam_policy.node_secrets_policy.arn
}

# Create the Kubernetes service account
resource "kubernetes_service_account" "fargate_sa" {
  metadata {
    name      = "${var.project_name}-${var.env}-fargate-sa"
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fargate_sa_role.arn
    }
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# IAM roles and policies and Service Accounts for the individual models
resource "kubernetes_service_account" "model_sa" {
  for_each = var.models
  metadata {
    name      = "${each.key}-karpenter-sa"
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.model_role[each.key].arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.model_policy_attach
  ]
}


resource "aws_iam_role" "model_role" {
  for_each = var.models

  name = "${var.project_name}-${var.env}-eks-${each.key}-karpenter-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = module.eks.oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:default:${each.key}-karpenter-sa",
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
  tags = var.tags
}

resource "aws_iam_policy" "model_policy" {
  for_each = var.models

  name = "${var.project_name}-${var.env}-eks-${each.key}-karpenter-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Cross-account ECR access
      [
        {
          Effect = "Allow"
          Action = [
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ecr:BatchCheckLayerAvailability"
          ]
          Resource = [
            "arn:aws:ecr:${var.aws_region}:${var.shared_account_id}:repository/${var.project_name}-shared-eks-*"
          ]
        },
        {
          Effect   = "Allow"
          Action   = ["ecr:GetAuthorizationToken"]
          Resource = ["*"]
        }
      ],

      # Rekognition, for those models that need it
      each.value.needs_rekognition ? [
        {
          Effect = "Allow"
          Action = [
            "rekognition:CompareFaces",
            "rekognition:DetectFaces",
            "rekognition:DetectLabels",
            "rekognition:DetectModerationLabels",
            "rekognition:DetectText",
            "rekognition:GetCelebrityInfo",
            "rekognition:RecognizeCelebrities",
            "rekognition:ListCollections",
            "rekognition:ListFaces",
            "rekognition:SearchFaces",
            "rekognition:SearchFacesByImage",
            "rekognition:CreateCollection",
            "rekognition:DeleteCollection",
            "rekognition:IndexFaces",
            "rekognition:DeleteFaces"
          ]
          Resource = ["*"]
        }
      ] : [],

      # SQS permissions - only for models that need it
      # FIXME: Pin down what queues are needed
      each.value.needs_sqs ? [
        {
          Effect = "Allow"
          Action = [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes",
            "sqs:SendMessage",
            "sqs:ChangeMessageVisibility"
          ]
          Resource = [
            "*"
            #"arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${split("/", lookup(var.sqs_queues, each.key, ""))[4]}"
          ]
        }
      ] : [],
      # Other AWS service permissions
      [
        {
          Effect = "Allow"
          Action = [
            "s3:*",
            "s3:PutBucketCORS"
          ]
          Resource = "*"
        }
      ],
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
      [
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:GetSecretValue",
            "secretsmanager:DescribeSecret"
          ]
          Resource = [
            "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-${var.env}*",
            "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:mediaviz-k8s-secrets",
            "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-serverless-${var.env}-aurora-credentials-pg*",
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:GenerateDataKey*"
          ]
          Resource = "*" # Changed from var.kms_key_arn to *
        }
      ]
    )
  })
  tags = var.tags
}


resource "aws_iam_role_policy_attachment" "model_policy_attach" {
  for_each   = var.models
  role       = aws_iam_role.model_role[each.key].name
  policy_arn = aws_iam_policy.model_policy[each.key].arn
}

# Manages the AWS Load Balancer Controller deployment

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = "${var.project_name}-${var.env}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json
}

data "aws_iam_policy_document" "aws_load_balancer_controller" {
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTrustStores",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection",
    ]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateSecurityGroup"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:aws:ec2:*:*:security-group/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateSecurityGroup"]
    }

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateTags", "ec2:DeleteTags"]
    resources = ["arn:aws:ec2:*:*:security-group/*"]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress", "ec2:DeleteSecurityGroup"]
    resources = ["*"]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:CreateTargetGroup"]
    resources = ["*"]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule",
    ]
    resources = ["*"]
  }

  statement {
    effect  = "Allow"
    actions = ["elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
    ]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup",
    ]
    resources = ["*"]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect  = "Allow"
    actions = ["elasticloadbalancing:AddTags"]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "elasticloadbalancing:CreateAction"
      values   = ["CreateTargetGroup", "CreateLoadBalancer"]
    }

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["elasticloadbalancing:RegisterTargets", "elasticloadbalancing:DeregisterTargets"]
    resources = ["arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule",
    ]
    resources = ["*"]
  }
}


resource "aws_iam_policy" "aws_load_balancer_controller" {
  policy = data.aws_iam_policy_document.aws_load_balancer_controller.json
  name   = "${var.project_name}-${var.env}-aws-load-balancer-controller"
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
  role       = aws_iam_role.aws_load_balancer_controller.name
}

resource "helm_release" "aws_load_balancer_controller" {
  chart            = "aws-load-balancer-controller"
  name             = "aws-load-balancer-controller"
  namespace        = "kube-system"
  repository       = "https://aws.github.io/eks-charts"
  version          = "1.8.0"
  create_namespace = true
  wait             = true
  timeout          = "900"


  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_load_balancer_controller.arn
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }
}

# k8s secrets

data "kubernetes_secret" "secrets" {
  metadata {
    name      = "mediaviz-k8s-secrets"
    namespace = "default"
  }
}

# Model deployments with Helm

resource "helm_release" "model_deployments" {
  for_each = local.helm_models

  name      = each.value.short_name
  namespace = var.namespace
  chart     = "${path.module}/chart/models"

  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = var.helm_timeout

  # Use inline values instead of templatefile
  set {
    name  = "image.repository"
    value = lookup(each.value, "image", "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-serverless-${var.env}-eks-${each.key}")
  }

  set {
    name  = "image.tag"
    value = lookup(each.value, "image_tag", "latest")
  }

  set {
    name  = "replicas"
    value = each.value.replicas
  }

  set {
    name  = "serviceAccountName"
    value = kubernetes_service_account.model_sa[each.key].metadata[0].name
  }

  set {
    name  = "serviceAccountRoleArn"
    value = aws_iam_role.model_role[each.key].arn
  }

  set {
    name  = "env.AWS_REGION"
    value = var.aws_region
  }

  set {
    name  = "env.ENVIRONMENT"
    value = var.env
  }

  set {
    name  = "env.MODEL_NAME"
    value = each.key
  }

  set {
    name  = "env.DB_CLUSTER_ARN"
    value = var.aurora_cluster_arn
  }

  set {
    name  = "env.DB_SECRET_ARN"
    value = var.aurora_secret_arn
  }

  set {
    name  = "env.DB_NAME"
    value = var.aurora_database_name
  }

  set {
    name  = "env.DB_KEYS_NAME"
    value = var.aurora_secret_name
  }

  set {
    name  = "env.DB_READ_HOST"
    value = var.aurora_ro_hostname
  }

  set {
    name  = "env.DB_WRITE_HOST"
    value = var.aurora_rw_hostname
  }

  # Conditionally set SQS URL if needed
  dynamic "set" {
    for_each = each.value.needs_sqs ? [1] : []
    content {
      name  = "env.SQS_QUEUE_URL"
      value = lookup(var.sqs_queues, each.key, "")
    }
  }

  set {
    name  = "env.LOG_LEVEL"
    value = var.log_level
  }

  set {
    name  = "env.GRPC_SERVER_PORT"
    value = lookup(each.value, "grpc_server_port", "0.0.0.0:50051")
  }


  # Resource and limits
  set {
    name  = "resources.limits.cpu"
    value = each.value.resources.limits.cpu
  }

  set {
    name  = "resources.limits.memory"
    value = each.value.resources.limits.mem
  }

  set {
    name  = "resources.requests.cpu"
    value = each.value.resources.requests.cpu
  }

  set {
    name  = "resources.requests.memory"
    value = each.value.resources.requests.mem
  }

  # not every service requests or limits by storage
  dynamic "set" {
    for_each = can(each.value.resources.limits.storage) ? [1] : []
    content {
      name  = "resources.limits.ephemeral-storage"
      value = each.value.resources.limits.storage
    }
  }

  dynamic "set" {
    for_each = can(each.value.resources.requests.storage) ? [1] : []
    content {
      name  = "resources.requests.ephemeral-storage"
      value = each.value.resources.requests.storage
    }
  }

  # not every service requests or limits by GPU
  dynamic "set" {
    for_each = can(each.value.resources.limits.gpu) ? [1] : []
    content {
      name  = "resources.limits.nvidia\\.com/gpu"
      value = each.value.resources.limits.gpu
    }
  }

  dynamic "set" {
    for_each = can(each.value.resources.requests.gpu) ? [1] : []
    content {
      name  = "resources.requests.nvidia\\.com/gpu"
      value = each.value.resources.requests.gpu
    }
  }

  # GPU tolerations for GPU models
  # Do we actually need this bit if we're setting requests/limits appropriately?
  dynamic "set" {
    for_each = each.value.needs_gpu ? [1] : []
    content {
      name  = "tolerations[0].key"
      value = "nvidia.com/gpu"
    }
  }

  dynamic "set" {
    for_each = each.value.needs_gpu ? [1] : []
    content {
      name  = "tolerations[0].value"
      value = "true"
      type  = "string"
    }
  }

  dynamic "set" {
    for_each = each.value.needs_gpu ? [1] : []
    content {
      name  = "tolerations[0].effect"
      value = "NoSchedule"
    }
  }

  # External API needs a number of additional environment variables
  dynamic "set" {
    for_each = contains(["external-api"], each.key) ? [1] : []
    content {
      name  = "targetPort"
      value = tostring("8000")
    }
  }

  dynamic "set" {
    for_each = contains(["external-api"], each.key) ? [1] : []
    content {
      name  = "SECRET_KEY"
      value = true
    }
  }
  dynamic "set" {
    for_each = contains(["external-api"], each.key) ? [1] : []
    content {
      name  = "env.ACCESS_TOKEN_EXPIRE_MINUTES"
      value = tostring(300)
    }
  }
  dynamic "set" {
    for_each = contains(["external-api"], each.key) ? [1] : []
    content {
      name  = "env.REFRESH_TOKEN_EXPIRE_DAYS"
      value = tostring(30)
    }
  }
  dynamic "set" {
    for_each = contains(["external-api"], each.key) ? [1] : []
    content {
      name  = "FRONTEND_URL"
      value = true
    }
  }
  dynamic "set" {
    for_each = contains(["external-api"], each.key) ? [1] : []
    content {
      name  = "env.CORS_ALLOW_ORIGINS"
      value = "*"
    }
  }
  dynamic "set" {
    for_each = contains(["external-api"], each.key) ? [1] : []
    content {
      name  = "SIMILARITY_QUEUE_URL"
      value = true
    }
  }
  dynamic "set" {
    for_each = contains(["external-api"], each.key) ? [1] : []
    content {
      name  = "EVIDENCE_QUEUE_URL"
      value = true
    }
  }
  dynamic "set" {
    for_each = contains(["external-api"], each.key) ? [1] : []
    content {
      name  = "PERSONHOOD_QUEUE_URL"
      value = true
    }
  }
  dynamic "set" {
    for_each = contains(["external-api"], each.key) ? [1] : []
    content {
      name  = "env.ALGORITHM"
      value = "HS256"
    }
  }

  dynamic "set" {
    for_each = contains(["evidence-model"], each.key) ? [1] : []
    content {
      name  = "SIMILARITY_SET_SORTING_SERVICE_QUEUE_URL"
      value = true
    }
  }

  dynamic "set" {
    for_each = contains(["similarity-set-sorting-service"], each.key) ? [1] : []
    content {
      name  = "env.SQS_QUEUE_URL"
      value = "https://sqs.us-east-2.amazonaws.com/379283424934/mediaviz-dev-eks-similarity-set-sorting-service-queue"
    }
  }

  # If we've specified a workload-type nodeSelector, then use that
  # Otherwise, default to the primary workload type
  set {
    name  = "nodeSelector.workload-type"
    value = lookup(each.value, "workload-type", "primary")
  }

  set {
    name  = "fullnameOverride"
    value = "${each.value.short_name}-karpenter"
  }
}

