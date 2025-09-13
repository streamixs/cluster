module "argocd" {
  source = "./resources/argocd"
}

module "argo-rollouts" {
  source = "./resources/argo-rollouts"

}
module "nginx-ingress-controller" {
  source = "./resources/nginx-ingress-controller"
}