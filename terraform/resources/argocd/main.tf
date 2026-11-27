terraform {
  required_version = ">= 1.3.0"
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
  }
}

locals {
  # OIDC est active uniquement quand le client Pocket-ID et l'email admin
  # sont fournis. Sans ces variables, le bootstrap reste identique.
  oidc_enabled = var.argocd_oidc_client_id != "" && var.argocd_oidc_admin_email != ""
}

# Secret separe pour que le client secret OIDC ne soit pas dans les values
# Helm ni dans Git. ArgoCD le lit via $argocd-oidc:client-secret.
resource "kubernetes_secret" "argocd_oidc" {
  count = local.oidc_enabled ? 1 : 0

  metadata {
    name      = "argocd-oidc"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/part-of" = "argocd"
      "app.kubernetes.io/name"    = "argocd-oidc"
    }
  }

  data = {
    "client-secret" = var.argocd_oidc_client_secret
  }

  depends_on = [kubernetes_namespace.argocd]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false
  version          = var.chart_version

  values = concat(
    [file(var.values_file)],
    local.oidc_enabled ? [
      templatefile("${path.module}/argocd-oidc-values.yaml.tpl", {
        client_id   = var.argocd_oidc_client_id
        admin_email = var.argocd_oidc_admin_email
      })
    ] : []
  )

  depends_on = [
    kubernetes_namespace.argocd,
    kubernetes_secret.argocd_oidc,
  ]

  lifecycle {
    precondition {
      condition     = (var.argocd_oidc_client_id == "") == (var.argocd_oidc_admin_email == "")
      error_message = "argocd_oidc_client_id and argocd_oidc_admin_email must be set together."
    }

    precondition {
      condition     = !local.oidc_enabled || length(var.argocd_oidc_client_secret) > 0
      error_message = "argocd_oidc_client_secret must be set when OIDC is enabled."
    }
  }
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
      error_message = "SOPS age key file does not exist at path: ${var.sops_age_key_file}"
    }
  }

  depends_on = [kubernetes_namespace.argocd]
}

