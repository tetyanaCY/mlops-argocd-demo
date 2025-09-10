provider "aws" { region = var.aws_region }

data "aws_eks_cluster" "this"      { name = var.cluster_name }
data "aws_eks_cluster_auth" "this" { name = var.cluster_name }

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

resource "kubernetes_namespace" "argocd_ns" {
  metadata { name = var.namespace }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = kubernetes_namespace.argocd_ns.metadata[0].name
  create_namespace = false

  values  = [file("${path.module}/values/argocd-values.yaml")]
  timeout = 600
  wait    = true
  atomic  = true
}
