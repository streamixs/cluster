terraform {
  required_version = ">= 1.3.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38.0"
    }
  }
}

module "argocd" {
  source = "./resources/argocd"
}

module "argo-rollouts" {
  source = "./resources/argo-rollouts"
}