## List of apps

Arborescence des applications gérées par Argo CD (ApplicationSet). Chaque sous-dossier correspond à une `Application`.

### Applications actuelles
- `argocd/`: IngressRoute ArgoCD (installation via Terraform)
- `argo-rollouts/`: installe Argo Rollouts via manifest upstream
- `cert-manager/`: installe cert-manager + Issuers/Certificates (namespace `kube-system`)
- `cilium/`: CNI + L2 announcements (namespace `kube-system`)
- `cloudnative-pg/`: opérateur PostgreSQL (namespace `cnpg-system`)
- `external-services/`: Services + EndpointSlice pour Pocket-ID, Home Assistant, TrueNAS
- `hermes/`: agent Hermes, gateway Telegram (namespace `hermes`)
- `immich/`: galerie photo + PostgreSQL CNPG (namespace `immich`)
- `intel-gpu-plugin/`: device plugin i915 (namespace `kube-system`)
- `longhorn/`: stockage répliqué (namespace `longhorn-system`)
- `media/`: stack media (namespace `media`)
- `monitoring/`: kube-prometheus-stack + Loki + Promtail (namespace `monitoring`)
- `securo/`: gestionnaire de finances + PostgreSQL CNPG (namespace `securo`)
- `traefik/`: ingress controller (namespace `traefik`)
- `traefik-forward-auth/`: auth Pocket-ID (namespace `auth`)

### Ajouter une nouvelle application
1) Créer un dossier `argocd/apps/<app-name>` avec l’un des modèles:
   - Kustomize: `kustomization.yaml` référencant des `resources` (manifests ou bases)
   - Helm via Kustomize: bloc `helmCharts` dans `kustomization.yaml`
2) Commit/push sur `main` via PR.
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
- Le namespace par défaut de destination est le nom du dossier (`{{path.basename}}`), mais les kustomizations peuvent déployer ailleurs.
- Pour changer la branche/chemin, modifier `argocd/bootstrap/app-of-apps.yaml`.
