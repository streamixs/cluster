terraform {
  required_version = ">= 1.3.0"
}

resource "kubernetes_namespace" "argo-rollouts" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "argo-rollouts" {
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  namespace        = kubernetes_namespace.argo-rollouts.metadata[0].name
  create_namespace = false
  version          = var.chart_version

  values = [
    file(var.values_file)
  ]

  depends_on = [
    kubernetes_namespace.argo-rollouts
  ]
}