terraform {
  required_version = ">= 1.3.0"
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false
  version          = var.chart_version

  values = [
    file("${path.module}/argocd-values.yaml")
  ]
}

// removed kubectl resource; rely on kubernetes provider to read secret via data source


