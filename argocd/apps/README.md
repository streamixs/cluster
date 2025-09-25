## List of apps

Arborescence des applications gérées par Argo CD (ApplicationSet). Chaque sous-dossier correspond à une `Application`.

### Applications actuelles
- `argo-rollouts/`: installe Argo Rollouts via manifest upstream
- `cert-manager/`: installe cert-manager + Issuers/Certificates (namespace `kube-system`)
- `ingress-nginx/`: installe l'ingress controller (namespace `kube-system`)
- `loki/`: installe loki (namespace `loki`)

### Ajouter une nouvelle application
1) Créer un dossier `argocd/apps/<app-name>` avec l’un des modèles:
   - Kustomize: `kustomization.yaml` référencant des `resources` (manifests ou bases)
   - Helm via Kustomize: bloc `helmCharts` dans `kustomization.yaml`
2) Commit/push sur la branche ciblée par le bootstrap (`targetRevision`).
3) Argo CD créera automatiquement l’`Application` (naming = `path.basename`).

Exemple (Helm via Kustomize):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: my-namespace
helmCharts:
  - name: my-chart
    repo: https://charts.example.com
    releaseName: my-chart
    version: 1.2.3
    valuesFile: values.yaml
```

### Notes
- L’ApplicationSet définit `CreateNamespace=true`, `PruneLast=true`, `ServerSideApply=true`, `ApplyOutOfSyncOnly=true`.
- Le namespace par défaut de destination est le nom du dossier (`{{path.basename}}`).
- Pour changer la branche/chemin, modifier `argocd/bootstrap/app-of-apps.yaml`.
