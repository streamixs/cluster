# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kubernetes cluster infrastructure managed via GitOps. **Talos Linux** as OS, **Cilium** as CNI (kube-proxy replacement), **ArgoCD** for continuous delivery.

Two environments:
- **dev** — Docker-based local cluster (`talosctl cluster create docker`), 1 control plane + 2 workers
- **prod** — Bare metal mini PCs, 1 control plane + 3 workers (192.168.1.30 / .40 / .41 / .42)

## Common Commands

```bash
# Bootstrap full cluster (dev): Talos + Cilium + ArgoCD
make bootstrap

# Bootstrap prod (manual steps, see Makefile)
make talos-gen-secret ENV=prod
make talos-gen ENV=prod
# Apply configs via talosctl apply-config + bootstrap, then:
make cilium ENV=prod
make argocd ENV=prod

# Cluster status (nodes + pods)
make status
make status ENV=prod

# Upgrades (prod only, dry-run first)
make k8s-upgrade-check K8S_VERSION=v1.35.3
make k8s-upgrade K8S_VERSION=v1.35.3
make talos-upgrade-check TALOS_VERSION=v1.12.6
make talos-upgrade TALOS_VERSION=v1.12.6
make etcd-backup            # snapshot avant tout upgrade

# Teardown dev only
make destroy

# YAML linting (runs in CI on PRs)
yamllint -c .yamllint.yaml .
```

## Architecture

### GitOps Flow

ArgoCD uses an **ApplicationSet** (`argocd/bootstrap/app-of-apps.yaml`) that auto-discovers applications by scanning `argocd/apps/*` directories. Each subdirectory becomes an ArgoCD Application automatically. The namespace defaults to the directory name.

> Note: l'ApplicationSet pointe actuellement sur la branche `feat/media-music-stack`. A migrer vers `main` (cf. ROADMAP.md).

### Directory Conventions

- **`argocd/apps/<app-name>/`** — Each directory is auto-discovered as an ArgoCD Application. Contains either a `kustomization.yaml` (for Kustomize apps) or a Helm chart reference (with `values.yaml`). Adding a new directory here is sufficient to deploy a new app.
- **`argocd/base/`** — Kustomize bases referenced by apps. Shared manifests (Deployments, Services, PVCs, IngressRoutes) live here.
- **`argocd/bootstrap/`** — The ApplicationSet and AppProject definitions. Rarely modified.
- **`argocd/projects/`** — ArgoCD AppProject definitions. New Helm repos must be added to `platform.yaml`'s `sourceRepos`.
- **`talos/dev/` and `talos/prod/`** — Talos machine configs via `talhelper`. Generated configs go to `clusterconfig/` (gitignored in dev, committed in prod for traceability).
- **`terraform/`** — Only handles ArgoCD Helm install + SOPS age key secret. Not used for other apps.

### Apps deployees

`argocd/apps/`:
- **argocd** — auto-management via app-of-apps
- **argo-rollouts** — progressive delivery
- **cert-manager** — wildcard `*.streamixs.com` via Cloudflare DNS01
- **cilium** — CNI + kube-proxy replacement + L2 announcements
- **cloudnative-pg** — operator Postgres (utilise par Immich)
- **external-services** — ExternalName services (Home Assistant, TrueNAS, Pocket-ID)
- **immich** — galerie photo, backed par CloudNativePG
- **longhorn** — storage replique pour les PVC RWO (configs des apps)
- **media** — stack media (voir ci-dessous)
- **traefik** — ingress controller (LoadBalancer via Cilium L2)
- **traefik-forward-auth** — auth via Pocket-ID en middleware

### Stack media (`argocd/apps/media`)

12 composants, tous dans le namespace `media` :
- **qbittorrent** — downloader principal
- **qbittorrent-seed** — instance dediee au seeding c411 (dossier NFS `seed-c411/`, port BT 30882)
- **prowlarr** — indexer manager
- **sonarr** / **radarr** / **lidarr** — *arr stack (series / films / musique)
- **plex** — serveur media (gere aussi la musique)
- **jellyseerr** — interface de requetes
- **mixarr** — playlist generator (avec MariaDB bundled)
- **tautulli** — analytics Plex
- **qui** — UI de gestion qBittorrent

### Storage

NFS via **democratic-csi** + **TrueNAS** (192.168.1.5).

Datasets sur TrueNAS :
```
main/{dev,prod}/media        # films, series, musique (PV statique, ReadWriteMany)
main/{dev,prod}/downloads    # telechargements (PV statique, ReadWriteMany)
applications/{dev,prod}      # parent pour democratic-csi (datasets auto par PVC)
```

Le PV statique `media-pv` mount le NFS (`192.168.1.10:/mnt/data/media`, 9Ti, RWX, NFS v4).
Les PVC de config des apps utilisent `longhorn` (RWO, replique sur les workers).

Setup TrueNAS :
1. Creer les datasets
2. Activer NFS (Network > NFS) + creer les shares
3. Creer une API key (Credentials > API Keys > Add)
4. Mettre la cle dans `argocd/apps/democratic-csi/values.yaml`

### Secrets Management

SOPS + Age encryption. La cle age est dans `.config/age.agekey` (gitignored).
KSOPS est injecte dans le repoServer ArgoCD via init container (config dans `terraform/resources/argocd/argocd-values.yaml`).
Convention : fichiers chiffres en `.sops.yaml`.

### Auth

Toutes les UI sensibles (ArgoCD, Sonarr, Radarr, Prowlarr, qBittorrent, etc.) passent par le middleware Traefik `forward-auth` (namespace `auth`) qui delegue a **Pocket-ID** (OIDC).

### Adding a New Application

1. Creer `argocd/apps/<app-name>/kustomization.yaml` (l'ApplicationSet le decouvre automatiquement)
2. Si l'app utilise un nouveau repo Helm, l'ajouter dans `argocd/projects/platform.yaml` `sourceRepos`
3. Si l'app a besoin de manifests custom, creer une base dans `argocd/base/<app-name>/`
4. Si secret, utiliser SOPS + KSOPS generator

### Key Config Details

- ArgoCD : branche cible `feat/media-music-stack` (a migrer vers `main`)
- Dev kubeconfig : `~/.talos/kubeconfig-dev`
- Prod kubeconfig : `~/.talos/kubeconfig-prod`
- Tous les ingresses utilisent le wildcard `*.streamixs.com` (cert-manager + Cloudflare DNS01)
- Talos versions : `v1.12.6` (Makefile default), Kubernetes `v1.35.3` (prod) / `v1.35.0` (dev)
- YAML style : 2-space indent, max 140 char lines, no document-start markers

## CI

GitHub Actions :
- `validate-manifests.yml` : `yamllint` sur les PRs
- `secret-scan.yml` : detection de secrets en clair

Config yamllint dans `.yamllint.yaml`. Le fichier `argocd/base/cert-manager/issuers/secret-cf-token.yaml` est exclu (SOPS-encrypted).

## Documents associes

- `README.md` — Quickstart utilisateur
- `TODO.md` — Backlog priorise (P0 securite -> P4 prod-ready)
- `ROADMAP.md` — Retrospective complete + plan d'amelioration moyen terme
