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

### AppProject `platform`

Le projet `platform` n'autorise plus `destinations: "*"` : chaque namespace de
destination est liste explicitement, ainsi que les kinds cluster-scoped
réellement rendus par les apps.

L'ApplicationSet utilise le nom du dossier comme namespace de destination
(`argocd/apps/<app>`). Une app qui déploie ailleurs via sa `kustomization`
utilise les deux namespaces : ajouter les deux à `destinations`.

Lors de l'ajout d'une app :

1. Ajouter le nom du dossier à `destinations`.
2. Si la `kustomization` force un autre namespace, l'ajouter aussi.
3. Si l'app crée un kind cluster-scoped (CRD, ClusterRole, webhook,
   StorageClass, etc.), l'ajouter à `clusterResourceWhitelist`.
4. Appliquer avec `make gitops`.

`namespaceResourceWhitelist` reste `"*"` : le périmètre est déjà limité par les
namespaces de destination. Une restriction par type pourra être faite app par
app si nécessaire.

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
