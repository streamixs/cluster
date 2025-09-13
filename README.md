## Cluster

Short docs and navigation. See module READMEs for details.

### Modules
- Argo CD: [`terraform/resources/argocd/README.md`](terraform/resources/argocd/README.md)
- Argo Rollouts: [`terraform/resources/argo-rollouts/README.md`](terraform/resources/argo-rollouts/README.md)
- Nginx Ingress Controller: [`terraform/resources/nginx-ingress-controller/README.md`](terraform/resources/argo-rollouts/README.md)

### Get started
```bash
cd terraform
terraform init
cp terraform.tfvars.example terraform.tfvars  # edit kubeconfig path if needed
terraform apply
```

### Providers
Kubernetes and Helm are configured via `terraform/provider.tf`.
Set kubeconfig path via Terraform variable (recommended):
1) Copy and edit tfvars:
```bash
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars
```
2) Or pass on CLI:
```bash
terraform apply -var 'kubeconfig=/path/to/config'
```

