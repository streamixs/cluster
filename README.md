## Cluster

Short docs and navigation. See module READMEs for details.

### Modules
- Argo CD: [`terraform/resources/argocd/README.md`](terraform/resources/argocd/README.md)

### Get started
```bash
cd terraform
terraform init
terraform apply
```

### Providers
Kubernetes and Helm are configured via `terraform/provider.tf`.
Set kubeconfig path with:
```bash
export TF_VAR_kubeconfig=~/.kube/config
```

