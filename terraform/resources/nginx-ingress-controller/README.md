## Nginx Ingress Controller (Terraform Module)

Installs the ingress-nginx controller via Helm.

### Prerequisites
- Terraform >= 1.3
- Providers `kubernetes` and `helm` configured (see cluster README)

### Inputs
- `namespace` (string, default `nginx-ingress-controller`)
- `chart_version` (string, default `4.13.2`)
- `values_file` (string, default `resources/nginx-ingress-controller/nginx-ingress-controller-values.yaml`)

### Install
From `cluster/terraform`:
```bash
terraform init
cp terraform.tfvars.example terraform.tfvars  # edit kubeconfig path if needed
terraform apply
```

### What it installs
- Namespace `${var.namespace}`
- Helm chart `ingress-nginx` from `kubernetes/ingress-nginx`
- Service type LoadBalancer for the controller
- Metrics endpoint (10254) and optional ServiceMonitor

### Verify
```bash
kubectl -n nginx-ingress-controller get deploy,po,svc
kubectl get ingressclass
```

### Customize
Edit `nginx-ingress-controller-values.yaml` to change Service type, ingressClass, metrics, ServiceMonitor, etc.

### Notes
- Ensure your cluster supports LoadBalancer (Cloud LB or Cilium LB/IPAM).
- Pin chart versions to avoid unexpected upgrades.


