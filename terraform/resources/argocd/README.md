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
Depuis la racine du repo :

```bash
make argocd
```

Ou manuellement, depuis `terraform/` :

```bash
terraform init
cp terraform.tfvars.example terraform.tfvars  # kubeconfig prod par défaut
terraform apply
```

Terraform crée aussi le secret `sops-age` dans le namespace ArgoCD à partir de
`.config/age.agekey`. Le state local contient ce secret et le mot de passe admin
initial : voir `terraform/STATE.md`.

Après l'installation, appliquer l'AppProject et l'ApplicationSet :

```bash
make gitops
```

### Outputs
- `argocd_admin_password`: initial admin password from the Secret (plain text).

```bash
terraform output -raw argocd_admin_password
```

### Access UI
Port-forward (le serveur est en HTTP interne car `server.insecure: true`) :

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
open http://localhost:8080
```

### Customize
Edit `argocd-values.yaml` (service type, ingress, params, etc.).

### Notes
- Change the admin password after first login.
- Consider deleting `argocd-initial-admin-secret` after rotation.


