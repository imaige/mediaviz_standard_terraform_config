# Add provider configuration for kubernetes
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Add a wait condition
resource "time_sleep" "wait_for_cluster" {
  depends_on = [module.eks]
  create_duration = "30s"
}

resource "kubernetes_cluster_role_binding" "admin_users" {
  depends_on = [time_sleep.wait_for_cluster]

  metadata {
    name = "cluster-admin-group"
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