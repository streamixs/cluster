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

### Secrets

Managed with SOPS + Age. Key at `.config/age.agekey` (gitignored).
