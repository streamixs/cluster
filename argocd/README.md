## Argo CD manifests

Bootstrap et projets Argo CD pour l’environnement `prod`.

### Contenu
- `bootstrap/app-of-apps.yaml`: ApplicationSet pointant vers `argocd/apps` sur la branche `main`.
- `projects/platform.yaml`: projet `platform` autorisant les sources Helm/repos nécessaires.
- `apps/`: dossiers d’applications synchronisées (référencés par le bootstrap).

### Bootstrapping
1) Installer Argo CD (via Terraform: `terraform/`)
2) Appliquer le projet et l’app de bootstrap:
```bash
kubectl apply -k argocd
# ou
make gitops
```

Argo CD synchronise le contenu de `argocd/apps/*`. Chaque sous-dossier devient une `Application`.

### Paramètres clés
- Repo: `https://github.com/streamixs/cluster`
- Branche (`targetRevision`): `main`
- Chemin: `argocd/apps/*` via ApplicationSet
- Options de sync: `automated: { prune, selfHeal }`, `CreateNamespace=true`, `PruneLast=true`, `ServerSideApply=true`, `ApplyOutOfSyncOnly=true`

### Applications gérées
Voir `argocd/apps/README.md`.

### Troubleshooting
- L’app reste OutOfSync:
  - Vérifie les droits du `AppProject` (`sourceRepos`, `destinations`).
  - Vérifie que la branche/chemin existent.
- Erreurs de création de namespaces/CRDs: assure `CreateNamespace=true` et que les CRDs nécessaires sont déjà installées.
