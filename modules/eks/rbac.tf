# rbac.tf

# Add provider configuration for kubernetes
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}

# Add Helm provider for add-on installations
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}


# Add a wait condition to ensure the cluster is available before applying RBAC
resource "time_sleep" "wait_for_cluster" {
  depends_on = [module.eks]
  create_duration = "30s"
}

# Create a ClusterRoleBinding for admin users
resource "kubernetes_cluster_role_binding" "admin_users" {
  count = var.create_kubernetes_resources ? 1 : 0
  depends_on = [time_sleep.wait_for_cluster]

  metadata {
    name = "cluster-admin-group"
    annotations = {
      "rbac.authorization.kubernetes.io/autoupdate" = "true"
    }
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "Group"
    name      = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }
}

# Create a Role and RoleBinding for developers (optional)
resource "kubernetes_role" "developer" {
  count = var.create_developer_role ? 1 : 0
  depends_on = [time_sleep.wait_for_cluster]

  metadata {
    name      = "developer"
    namespace = "default"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  rule {
    api_groups = ["", "apps", "batch"]
    resources  = ["pods", "services", "deployments", "configmaps", "secrets", "jobs"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log", "pods/exec"]
    verbs      = ["get", "list", "create"]
  }
}

resource "kubernetes_role_binding" "developer" {
  count = var.create_developer_role ? 1 : 0
  depends_on = [time_sleep.wait_for_cluster]

  metadata {
    name      = "developer-binding"
    namespace = "default"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.developer[0].metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "developer"
    api_group = "rbac.authorization.k8s.io"
  }
}

# Create an IAM policy document allowing IAM Principal to authenticate to Kubernetes cluster
resource "aws_iam_policy" "eks_admin_policy" {
  name        = "${var.project_name}-${var.env}-eks-admin-policy"
  description = "Policy allowing IAM principals to authenticate to the EKS cluster"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi"
        ]
        Resource = module.eks.cluster_arn
      },
      {
        Effect = "Allow"
        Action = [
          "eks:AccessKubernetesApi",
          "eks:ListAccessEntries",
          "eks:ListAccessPolicies"
        ]
        Resource = module.eks.cluster_arn
      }
    ]
  })
}