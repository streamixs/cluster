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
- `traefik-forward-auth/`: app historiquement nommée ainsi ; déploie
  `oauth2-proxy` pour l'auth Pocket-ID (namespace `auth`)

### Ajouter une nouvelle application
1) Créer un dossier `argocd/apps/<app-name>` avec l’un des modèles:
   - Kustomize: `kustomization.yaml` référencant des `resources` (manifests ou bases)
   - Helm via Kustomize: bloc `helmCharts` dans `kustomization.yaml`
2) Commit/push sur `main` via PR.
3) Argo CD créera automatiquement l’`Application` (naming = `path.basename`).

Checklist avant merge :

- [ ] Le namespace de destination est correct (ou géré explicitement).
- [ ] Les repos Helm/OCI sont dans `argocd/projects/platform.yaml` `sourceRepos`.
- [ ] Les secrets utilisent SOPS + KSOPS (`generators/secret-generator.yaml`).
- [ ] L’image est épinglée et suivie par Renovate.
- [ ] Probes, resources et securityContext sont définis.
- [ ] PSS et NetworkPolicy sont prises en compte.
- [ ] `kustomize build --enable-helm` passe (ou l’app est validée par la CI).

Exemple de secret KSOPS :

```yaml
# argocd/base/<app>/generators/secret-generator.yaml
apiVersion: viaduct.ai/v1
kind: ksops
metadata:
  name: secret-generator
  annotations:
    config.kubernetes.io/function: |
      exec:
        path: ksops
files:
  - secrets/<app>-secret.yaml
```

Puis dans `kustomization.yaml` :

```yaml
generators:
  - generators/secret-generator.yaml
```

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
- Le namespace par défaut de destination est le nom du dossier (`{{path.basename}}`), mais les kustomizations peuvent déployer ailleurs. Cela peut créer des namespaces vides (`cert-manager`, `cilium`, `cloudnative-pg`, `intel-gpu-plugin`, `longhorn`, `traefik-forward-auth`) : à corriger ou documenter.
- Pour changer la branche/chemin, modifier `argocd/bootstrap/app-of-apps.yaml`.
- `make argocd` installe ArgoCD ; `make gitops` crée l’AppProject et l’ApplicationSet.
- Les apps d’infrastructure **doivent** se synchroniser manuellement. Voir `docs/change-control.md`.
