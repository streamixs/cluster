## kube-prometheus-stack (Terraform Module)

Installs Prometheus, Alertmanager and Grafana using the `kube-prometheus-stack` Helm chart and enables cluster-wide discovery of ServiceMonitor/PodMonitor.

### Prerequisites
- Terraform >= 1.3
- Providers `kubernetes` and `helm` configurés (voir `cluster/README.md`)
- Un cluster avec droits pour créer CRDs et ressources dans `monitoring` (namespace par défaut)

### Inputs
- `namespace` (string, default `monitoring`)
- `chart_version` (string, default as pinned in `variables.tf`)
- `values_file` (string, default `resources/kube-prometheus-stack/kube-prometheus-stack-values.yaml`)

### What this module does
- Crée le namespace `${var.namespace}`
- Installe le chart `kube-prometheus-stack` (Prometheus, Alertmanager, Grafana)
- Active la découverte globale des `ServiceMonitor` et `PodMonitor` via:
  - `prometheus.prometheusSpec.serviceMonitorSelector{,NamespaceSelector}: {}`
  - `prometheus.prometheusSpec.podMonitorSelector{,NamespaceSelector}: {}`
- (Optionnel) Provisionne des dashboards Grafana si définis dans `grafana.dashboards.default`

### Install
Depuis `cluster/terraform`:
```bash
terraform init
terraform apply
```

Pour éviter les erreurs de CRD manquantes, installe d’abord ce module si nécessaire:
```bash
terraform apply -target=module.kube-prometheus-stack
cp terraform.tfvars.example terraform.tfvars  # edit kubeconfig path if needed
terraform apply
```

### Grafana & Dashboards
- Accéder à Grafana:
```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
# http://localhost:3000  (user: admin, pass dans le secret ci-dessous)
```
- Mot de passe admin:
```bash
kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -D
```
- Dashboards auto-import: définis dans `kube-prometheus-stack-values.yaml` sous `grafana.dashboards.default` (ex: NGINX Ingress `gnetId: 9614`, Argo Rollouts `gnetId: 16017`). Assure-toi que la datasource s’appelle `Prometheus`.

### Scrape des apps (exemples)
- Argo Rollouts (dans `resources/argo-rollouts/argo-rollouts-values.yaml`):
  - `controller.metrics.enabled: true`
  - `controller.serviceMonitor.enabled: true`
  - `controller.serviceMonitor.namespace: <namespace où créer le ServiceMonitor>`
- NGINX Ingress Controller (dans `resources/nginx-ingress-controller/nginx-ingress-controller-values.yaml`):
  - `controller.metrics.enabled: true`
  - `controller.serviceMonitor.enabled: true`
  - `controller.serviceMonitor.namespace: <namespace où créer le ServiceMonitor>`

Avec la configuration par défaut de ce module, Prometheus sélectionne les ServiceMonitor/PodMonitor dans tous les namespaces.

### Vérifications rapides
- CRDs et ServiceMonitor:
```bash
kubectl get crd | grep -i monitoring.coreos.com
kubectl get servicemonitor -A | grep -E 'rollouts|ingress'
```
- Cibles Prometheus:
```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090
# http://localhost:9090/targets  → les jobs rollouts/nginx doivent être "up"
```
- Requêtes de test dans Prometheus/Grafana:
```
up{job=~".*rollouts.*"}
up{job=~".*nginx.*"}
```

### Troubleshooting
- "No data" dans Grafana:
  - Vérifier que la datasource Grafana pointe vers Prometheus du stack et est par défaut (nom `Prometheus`).
  - Réduire la fenêtre de temps (Last 5m) et attendre 1–3 minutes.
- ServiceMonitor absent: vérifier les valeurs `serviceMonitor.enabled` et le namespace choisi.
- Cibles "down": vérifier que les endpoints metrics répondent:
```bash
kubectl -n argo-rollouts port-forward deploy/argo-rollouts 8090:8090 &
curl -sf http://127.0.0.1:8090/metrics | head

kubectl -n nginx-ingress-controller port-forward deploy/nginx-ingress-controller 10254:10254 &
curl -sf http://127.0.0.1:10254/metrics | head
```


