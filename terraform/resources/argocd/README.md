## Argo CD (Terraform Module)

Installs Argo CD into a Kubernetes cluster via the official Helm chart.

### Prerequisites
- Terraform >= 1.3
- kubeconfig works (`kubectl get ns`)

### Inputs
- `namespace` (string, default `argocd`)
- `chart_version` (string)
- `values_file` (string, default `resources/argocd/argocd-values.yaml`)

### Install
From the root `cluster/terraform` directory:
```bash
terraform init
terraform apply
```

### Outputs
- `argocd_admin_password`: initial admin password from the Secret (plain text).

```bash
terraform output -raw argocd_admin_password
```

### Access UI
Port-forward:
```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
open https://localhost:8080
```

### Customize
Edit `argocd-values.yaml` (service type, ingress, params, etc.).

### Notes
- Change the admin password after first login.
- Consider deleting `argocd-initial-admin-secret` after rotation.


