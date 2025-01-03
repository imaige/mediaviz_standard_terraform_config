# Create ECR repositories for each model
resource "aws_ecr_repository" "repositories" {
  count = length(var.models)
  name  = "${var.prefix}-${var.models[count.index]}-repo"
}

# EKS IAM Role for Pod Access
resource "aws_iam_role" "eks_pod_role" {
  name = "${var.prefix}-eks-pod-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name = "sqs-access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes"
          ]
          Resource = var.sqs_arns
        }
      ]
    })
  }
}

# Kubernetes Deployment for each function
resource "kubernetes_deployment" "eks_functions" {
  count = length(var.models)

  metadata {
    name      = "${var.models[count.index]}-deployment"
    namespace = var.namespace
    labels = {
      app = "${var.models[count.index]}-app"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "${var.models[count.index]}-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "${var.models[count.index]}-app"
        }
      }

      spec {
        container {
          image = "${aws_ecr_repository.repositories[count.index].repository_url}:${var.image_tags[count.index]}"
          name  = "${var.models[count.index]}-container"

          env {
            name  = "SQS_QUEUE_URL"
            value = var.sqs_urls[count.index]
          }

          env {
            name  = "AWS_REGION"
            value = var.aws_region
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }

        service_account_name = var.service_account_name
      }
    }
  }
}
