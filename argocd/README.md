## Argo CD manifests

Bootstrap et projets Argo CD pour l’environnement `dev`.

### Contenu
- `bootstrap/app-of-apps.yaml`: Application Argo CD "app-of-apps" pointant vers `argocd/apps` sur la branche `develop`.
- `projects/platform.yaml`: Projet `platform` autorisant les sources Helm/repos nécessaires.
- `apps/`: dossiers/fichiers d’applications synchronisées (référencés par le bootstrap).

### Bootstrapping
1) Assure-toi qu’Argo CD est installé (via Terraform module `resources/argocd`).
2) Applique le projet et l’app de bootstrap:
```bash
kubectl apply -f projects/platform.yaml
kubectl apply -f bootstrap/app-of-apps.yaml
```

Argo CD va synchroniser tout le contenu de `argocd/apps` (récursif) depuis `branch: develop`.

### Paramètres clés
- Repo: `https://github.com/streamixs/cluster`
- Branch: `develop` (modifie `spec.source.targetRevision` si besoin)
- Chemin: `argocd/apps` (modifie `spec.source.path` pour une autre arbo)
- Options de sync: `automated: { prune, selfHeal }`, `CreateNamespace=true`, `PruneLast=true`, `ApplyOutOfSyncOnly=true`

### Promotion / Multi-envs
- Duplique `bootstrap/app-of-apps-<env>.yaml` et `projects/platform-<env>.yaml` en changeant labels/env, `targetRevision`, `path` si nécessaire.
- Utilise des branches par environnement (`develop`, `staging`, `main`) ou `spec.source.kustomize/helm` pour overlays/valeurs.

### Troubleshooting
- L’app reste OutOfSync:
  - Vérifie les droits du `AppProject` (`sourceRepos`, `destinations`).
  - Vérifie que la branche/chemin existent.
- Erreurs de création de namespaces/CRDs: assure `CreateNamespace=true` et que les CRDs nécessaires sont déjà installées.


