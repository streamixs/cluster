module "argocd" {
  source = "./resources/argocd"
}

module "argo-rollouts" {
  source = "./resources/argo-rollouts"

}
module "ngnix-ingress-controller" {
  source = "./resources/ngnix-ingress-controller"
}