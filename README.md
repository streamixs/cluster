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
