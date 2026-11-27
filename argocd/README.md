## Argo CD manifests

Bootstrap et projets Argo CD pour l’environnement `prod`.

### Contenu
- `bootstrap/app-of-apps.yaml`: ApplicationSet pointant vers `argocd/apps` sur la branche `main`.
- `projects/platform.yaml`: projet `platform` autorisant les sources Helm/repos nécessaires.
- `apps/`: dossiers d’applications synchronisées (référencés par le bootstrap).

### Bootstrapping
1) Installer Argo CD (via Terraform) :
```bash
make argocd
```
2) Appliquer le projet et l’ApplicationSet :
```bash
kubectl apply -k argocd
# ou
make gitops
```

`make argocd` seul ne crée **aucune** Application : il faut `make gitops`.

Argo CD synchronise le contenu de `argocd/apps/*`. Chaque sous-dossier devient une `Application`.

Les secrets sont déchiffrés par KSOPS dans le repo-server ArgoCD. La clé age
est montée depuis le secret `sops-age`, créé par Terraform.

### Paramètres clés
- Repo: `https://github.com/streamixs/cluster`
- Branche (`targetRevision`): `main`
- Chemin: `argocd/apps/*` via ApplicationSet
- Options de sync: `automated: { prune, selfHeal }`, `CreateNamespace=true`, `PruneLast=true`, `ServerSideApply=true`, `ApplyOutOfSyncOnly=true`

### Applications gérées
Voir `argocd/apps/README.md`.

### Sync manuelle

Les composants d'infrastructure (Cilium, Longhorn, CNPG, cert-manager, Traefik)
doivent être synchronisés manuellement ou dans une sync window. Voir
`docs/change-control.md`.

### Troubleshooting
- L’app reste OutOfSync:
  - Vérifie les droits du `AppProject` (`sourceRepos`, `destinations`).
  - Vérifie que la branche/chemin existent.
- Erreurs de création de namespaces/CRDs: assure `CreateNamespace=true` et que les CRDs nécessaires sont déjà installées.
- Erreur KSOPS / `sops-age` : vérifier que le secret `sops-age` existe dans
  `argocd` et que `.config/age.agekey` correspond au destinataire SOPS.
- Namespace vide inattendu : l’ApplicationSet utilise `{{path.basename}}` comme
  namespace de destination ; une app qui déploie ailleurs peut laisser un
  namespace vide.
