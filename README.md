## Cluster

Kubernetes cluster powered by **Talos Linux** + **ArgoCD** GitOps.

### Architecture

```
Talos Linux (OS) → Cilium (CNI) → ArgoCD (GitOps) → Apps
```

Un seul environnement permanent : **prod**. Le lab de test est jetable
(`kind`/`k3d`) et n'est jamais synchronisé avec les apps de prod.

| Env | Infra | Control planes | Workers |
|-----|-------|----------------|---------|
| prod | Mini PCs (bare metal) | 1 | 3 |

### Prerequisites

```bash
brew install siderolabs/tap/talosctl budimanjojo/tap/talhelper helm \
  kubernetes-cli terraform sops age yq jq
```

### Bootstrap prod (manuel)

```bash
make bootstrap                    # affiche la procédure
make talos-gen-secret             # génère + chiffre les secrets Talos
make talos-gen                    # génère les machine configs
# appliquer les configs avec talosctl apply-config sur chaque node
# puis talosctl bootstrap sur le premier control plane

make cilium                       # CNI Cilium
make argocd                       # ArgoCD via Terraform
make gitops                       # AppProject + ApplicationSet
make status                       # nodes + pods
```

Sans `make gitops`, ArgoCD est installé mais aucune Application n'est créée.

### Structure

- `talos/prod/` — configs Talos prod (talhelper)
- `terraform/` — installation ArgoCD + secret age
- `argocd/apps/` — Applications gérées par ArgoCD
- `argocd/base/` — bases Kustomize (media, cert-manager, etc.)
- `argocd/bootstrap/` — ApplicationSet + projets

### Storage (TrueNAS)

- **NFS statique** sur TrueNAS `192.168.1.10` :
  - `/mnt/data/media` → `media-pv` (9 Ti, RWX) pour films/séries/musique,
  - `/mnt/data/photos` → `immich-library-pv` (2 Ti, RWX) pour Immich.
- **Longhorn** pour les PVC RWO de configuration (2 réplicas sur les workers).

Les PV NFS sont déclarés dans `argocd/base/media-pvc/media-pv.yaml` et
`argocd/base/immich/immich-library-pv.yaml`. Il n'y a plus de democratic-csi
dans le repo.

### Secrets

Managed with SOPS + Age. Key at `.config/age.agekey` (gitignored).

### Workflow (trunk-based)

- **`main`** est la seule branche long-running. ArgoCD lit `main`.
- Tout passe par PR (feature, fix, chore, Renovate) → squash-merge sur `main`.
- **Conventional Commits requis** dans les titres de PR : `feat:`, `fix:`, `chore:`, `feat!:` (breaking), etc.
- Aucun merge direct sur `main`; les checks CI sont obligatoires.

### Testing avant merge

- La CI valide les manifests sur chaque PR (`yamllint`, `kustomize build`,
  `kubeconform`, `gitleaks`).
- Un lab `kind`/`k3d` peut être créé à la demande pour un test applicatif ;
  il n'est pas un environnement permanent.
- Le durcissement de la CI (KSOPS, schemas CRD, Terraform, Pluto) est suivi
  dans `TODO.md`.

### Releases (automatique)

[release-please](https://github.com/googleapis/release-please) maintient une *Release PR* permanente. Elle accumule les commits depuis le dernier tag :

- `feat:` → bump **minor**
- `fix:` / `perf:` → bump **patch**
- `feat!:` ou `BREAKING CHANGE:` → bump **major**

Quand tu merges la Release PR, release-please crée automatiquement le tag `vX.Y.Z`, met à jour `CHANGELOG.md` et publie une GitHub Release. Pas de tagging manuel.

### Dependency updates

[Renovate Bot](https://www.mend.io/renovate/) ouvre des PRs ciblant `main` pour bumper les images Docker, les charts Helm (`kustomize.helmCharts`), les actions GitHub et la version de gitleaks. Config dans [`.github/renovate.json5`](.github/renovate.json5).

- **Patches** (`x.y.Z`) : auto-merge active si la branch protection de `main` autorise l'auto-merge GitHub.
- **Minor / major** : PR a valider manuellement.
- **Talos / Kubernetes / installer Sidero** : exclus, upgrade pilote via `make k8s-upgrade-check` + `make etcd-backup`.
- **Schedule** : nuits de semaine (apres 22h) + weekends, fuseau Europe/Paris.
- La politique de commit des bumps est définie dans `.github/renovate.json5`.

Une *Dependency Dashboard* (issue auto-creee par Renovate) liste les PRs en cours et les bumps en attente.

Activation : installer [l'app Mend Renovate](https://github.com/apps/renovate) sur le repo `streamixs/cluster`.
