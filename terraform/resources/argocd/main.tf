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
    file(var.values_file)
  ]

  depends_on = [
    kubernetes_namespace.argocd
  ]
}

resource "kubernetes_secret" "sops-age" {
  metadata {
    name      = "sops-age"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  data = {
    "keys.txt" = file("${var.sops_age_key_file}")
  }
  lifecycle {
    precondition {
      condition     = fileexists(var.sops_age_key_file)
      error_message = "Sops age key file does not exist"
    }
  }

  depends_on = [ kubernetes_namespace.argocd ]
}

