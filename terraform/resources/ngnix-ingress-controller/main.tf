terraform {
  required_version = ">= 1.3.0"
}

resource "kubernetes_namespace" "nginx-ingress-controller" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "nginx-ingress-controller" {
  name             = "nginx-ingress-controller"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = kubernetes_namespace.nginx-ingress-controller.metadata[0].name
  create_namespace = false
  version          = var.chart_version

  values = [
    file(var.values_file)
  ]

  depends_on = [
    kubernetes_namespace.nginx-ingress-controller
  ]
}