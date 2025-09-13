## Argo Rollouts (Terraform Module)

Installs Argo Rollouts via the official Helm chart.

### Prerequisites
- Terraform >= 1.3
- Providers `kubernetes` and `helm` configured (see cluster README)

### Inputs
- `namespace` (string, default `argo-rollouts`)
- `chart_version` (string, default `2.40.4`)
- `values_file` (string, default `resources/argo-rollouts/argo-rollouts-values.yaml`)

### Install
From `cluster/terraform`:
```bash
terraform init
cp terraform.tfvars.example terraform.tfvars  # edit kubeconfig path if needed
terraform apply
```

### What it installs
- Namespace `${var.namespace}`
- Helm chart `argo-rollouts` from `argoproj/argo-helm`
- CRDs if `crds.install: true` (default enabled in values)
- Controller metrics on port 8090 with optional ServiceMonitor

### Verify
```bash
kubectl -n argo-rollouts get deploy,po,svc
kubectl api-resources | grep -i rollouts
```

Kubectl plugin (optional):
```bash
brew install argoproj/tap/kubectl-argo-rollouts
kubectl argo rollouts version
```

### Customize
Edit `argo-rollouts-values.yaml` for metrics, ServiceMonitor, etc.

### Notes
- If you disable CRDs here, apply them manually before using Rollouts.
- Pin chart versions to avoid unexpected upgrades.


