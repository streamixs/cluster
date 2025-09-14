## Cluster

Short docs and navigation. See module READMEs for details.

### Terraform modules (install only)
- Argo CD: [`terraform/resources/argocd/README.md`](terraform/resources/argocd/README.md)

### GitOps manifests (apps managed by Argo CD)
- Argo CD manifests: [`argocd/README.md`](argocd/README.md)
- Apps: [`argocd/apps/`](argocd/apps/) → Argo Rollouts, cert-manager, ingress-nginx

### Get started
```bash
# 1) Install Argo CD with Terraform
cd terraform
terraform init
cp terraform.tfvars.example terraform.tfvars  # edit kubeconfig path if needed
terraform apply

# 2) Bootstrap Argo CD (projects + app-of-apps)
cd ..
kubectl apply -f argocd/projects/platform.yaml
kubectl apply -f argocd/bootstrap/app-of-apps.yaml
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

### Notes
- Terraform now installs only Argo CD. All platform apps are reconciled by Argo CD from `argocd/apps/`.
- The bootstrap `targetRevision`/branch is defined in `argocd/bootstrap/app-of-apps.yaml`. Update it before bootstrapping.

