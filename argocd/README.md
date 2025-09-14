## Argo CD manifests

Bootstrap et projets Argo CD pour l’environnement `dev`.

### Contenu
- `bootstrap/app-of-apps.yaml`: Application Argo CD "app-of-apps" pointant vers `argocd/apps` sur la branche `develop`.
- `projects/platform.yaml`: Projet `platform` autorisant les sources Helm/repos nécessaires.
- `apps/`: dossiers/fichiers d’applications synchronisées (référencés par le bootstrap).

### Bootstrapping
1) Installer Argo CD (via Terraform: `cluster/terraform`)
2) Appliquer le projet et l’app de bootstrap:
```bash
kubectl apply -f projects/platform.yaml
kubectl apply -f bootstrap/app-of-apps.yaml
```

Argo CD synchronise le contenu de `argocd/apps/*`. Chaque sous-dossier devient une `Application`.

### Paramètres clés
- Repo: `https://github.com/streamixs/cluster`
- Branch (targetRevision): voir `bootstrap/app-of-apps.yaml` (actuellement la branche de feature)
- Chemin: `argocd/apps/*` via ApplicationSet
- Options de sync: `automated: { prune, selfHeal }`, `CreateNamespace=true`, `PruneLast=true`, `ServerSideApply=true`, `ApplyOutOfSyncOnly=true`

### Promotion / Multi-envs
- Dupliquer `bootstrap/app-of-apps-<env>.yaml` et `projects/platform-<env>.yaml` en ajustant labels/env, `targetRevision`, `path`.
- Utiliser des branches par environnement (`develop`, `staging`, `main`) ou des overlays Kustomize/valeurs Helm.

### Applications gérées
- `argo-rollouts`: installé via manifest upstream, namespace = `argo-rollouts`
- `cert-manager`: helm chart Jetstack, namespace = `kube-system`, inclut Issuers/Certs/SecretGenerator
- `ingress-nginx`: helm chart, namespace = `kube-system`

### Troubleshooting
- L’app reste OutOfSync:
  - Vérifie les droits du `AppProject` (`sourceRepos`, `destinations`).
  - Vérifie que la branche/chemin existent.
- Erreurs de création de namespaces/CRDs: assure `CreateNamespace=true` et que les CRDs nécessaires sont déjà installées.


