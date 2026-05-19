## Cluster

Kubernetes cluster powered by **Talos Linux** + **ArgoCD** GitOps.

### Architecture

```
Talos Linux (OS) → Cilium (CNI) → ArgoCD (GitOps) → Apps
```

| Env | Infra | Control Planes | Workers |
|-----|-------|---------------|---------|
| dev | Docker (talosctl) | 1 | 1 |
| prod | Mini PCs (bare metal) | 3 | N |

### Prerequisites

```bash
brew install siderolabs/tap/talosctl budimanjojo/tap/talhelper helm
```

### Quick start (dev)

```bash
make bootstrap        # cluster + cilium + argocd
make status           # nodes + pods
make destroy          # teardown
```

### Prod

```bash
make talos-gen-secret ENV=prod   # generate + encrypt secrets
make talos-gen ENV=prod          # generate machine configs
# Then apply configs manually with talosctl
make cilium ENV=prod
make argocd ENV=prod
```

### Structure

- `talos/` — Talos machine configs (dev + prod)
- `terraform/` — ArgoCD Helm install
- `argocd/apps/` — Applications managed by ArgoCD
- `argocd/base/` — Kustomize bases (media, cert-manager, etc.)
- `argocd/bootstrap/` — App-of-Apps + projects

### Storage (TrueNAS)

NFS storage via **democratic-csi** + TrueNAS (192.168.1.5).

Datasets a creer sur TrueNAS :

```
main/{dev,prod}/media        # films, series (PV statique, ReadWriteMany)
main/{dev,prod}/downloads    # telechargements (PV statique, ReadWriteMany)
applications/{dev,prod}      # parent pour democratic-csi (datasets auto par PVC)
```

Setup TrueNAS :
1. Creer les datasets ci-dessus
2. Activer le service NFS (Network > NFS)
3. Creer les shares NFS pour `main/dev/media` et `main/dev/downloads`
4. Creer une API key (Credentials > API Keys > Add)
5. Mettre la cle dans `argocd/apps/democratic-csi/values.yaml` (`driver.config.httpConnection.apiKey`)

### Secrets

Managed with SOPS + Age. Key at `.config/age.agekey` (gitignored).

### Workflow (trunk-based)

- **`main`** est la seule branche long-running. ArgoCD lit `main`.
- Tout passe par PR (feature, fix, chore, Renovate) → squash-merge sur `main`.
- **Conventional Commits requis** dans les titres de PR : `feat:`, `fix:`, `chore:`, `feat!:` (breaking), etc.

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
- Les bumps Renovate sont prefixes `chore(deps):` donc masques du CHANGELOG (volonte deliberee pour pas le polluer).

Une *Dependency Dashboard* (issue auto-creee par Renovate) liste les PRs en cours et les bumps en attente.

Activation : installer [l'app Mend Renovate](https://github.com/apps/renovate) sur le repo `streamixs/cluster`.
