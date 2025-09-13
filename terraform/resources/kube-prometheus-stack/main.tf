terraform {
  required_version = ">= 1.3.0"
}

resource "kubernetes_namespace" "kube-prometheus-stack" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "kube-prometheus-stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = kubernetes_namespace.kube-prometheus-stack.metadata[0].name
  create_namespace = false
  version          = var.chart_version

  values = [
    file(var.values_file)
  ]

  depends_on = [
    kubernetes_namespace.kube-prometheus-stack
  ]
}
