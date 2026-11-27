# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kubernetes cluster infrastructure managed via GitOps. **Talos Linux** as OS, **Cilium** as CNI (kube-proxy replacement), **ArgoCD** for continuous delivery.

Un seul environnement permanent :
- **prod** — Bare metal mini PCs, 1 control plane + 3 workers (192.168.1.30 / .40 / .41 / .42)

Le lab de test est **jetable** (`kind`/`k3d`) et n'est jamais synchronisé avec
les apps de prod. Il n'y a plus d'environnement `dev` permanent.

## Common Commands

```bash
# Bootstrap prod (procédure manuelle affichée par make)
make bootstrap

# Étapes prod
make talos-gen-secret
make talos-gen
# Apply configs via talosctl apply-config + bootstrap, then:
make cilium
make argocd
make gitops                 # AppProject + ApplicationSet

# Cluster status (nodes + pods)
make status

# Upgrades (dry-run first)
make k8s-upgrade-check K8S_VERSION=v1.35.3
make k8s-upgrade K8S_VERSION=v1.35.3
make talos-upgrade-check TALOS_VERSION=v1.12.6
make talos-upgrade TALOS_VERSION=v1.12.6
make etcd-backup            # snapshot avant tout upgrade

# YAML linting
yamllint -c .yamllint.yaml .
```

## Architecture

### GitOps Flow

ArgoCD uses an **ApplicationSet** (`argocd/bootstrap/app-of-apps.yaml`) that auto-discovers applications by scanning `argocd/apps/*` directories. Each subdirectory becomes an ArgoCD Application automatically. The namespace defaults to the directory name.

### Branch model (trunk-based)

- **`main`** est la seule branche long-running. ArgoCD lit `main`. Renovate ouvre ses PRs vers `main`.
- Toute modif passe par une PR : `feat/*`, `fix/*`, `chore/*`, `renovate/*` → `main` (squash-merge).
- **Conventional Commits obligatoires** (`feat:`, `fix:`, `chore:`, `BREAKING CHANGE:` dans le footer) — c'est release-please qui lit ces préfixes pour bumper la version.
- **release-please** (workflow `.github/workflows/release-please.yml`) maintient une "Release PR" permanente sur `main`. Quand on la merge, elle bumpe `.release-please-manifest.json`, met à jour `CHANGELOG.md`, crée le tag `vX.Y.Z` et la GitHub Release automatiquement.
- La branche `develop` n'est plus la cible : trunk-based, tout converge sur `main`. Elle reste à supprimer sur le remote.
- Les PR Renovate doivent être mergées **manuellement** : pas d'auto-merge, même si la CI est verte.
- Le workflow cible est PR obligatoire + checks requis + squash only + pas de force push. Voir `docs/change-control.md`.

### Directory Conventions

- **`argocd/apps/<app-name>/`** — Each directory is auto-discovered as an ArgoCD Application. Contains either a `kustomization.yaml` (for Kustomize apps) or a Helm chart reference (with `values.yaml`). Adding a new directory here is sufficient to deploy a new app.
- **`argocd/base/`** — Kustomize bases referenced by apps. Shared manifests (Deployments, Services, PVCs, IngressRoutes) live here.
- **`argocd/bootstrap/`** — The ApplicationSet and AppProject definitions. Rarely modified.
- **`argocd/projects/`** — ArgoCD AppProject definitions. New Helm repos must be added to `platform.yaml`'s `sourceRepos`.
- **`talos/prod/`** — Talos machine configs via `talhelper`. Les configs générées vont dans `clusterconfig/` (gitignored, régénérables depuis `talconfig.yaml` + `talsecret.sops.yaml`).
- **`terraform/`** — Only handles ArgoCD Helm install + SOPS age key secret. Not used for other apps. State local pour l'instant, voir `terraform/STATE.md`.
- **`docs/`** — Runbooks : bootstrap, testing, backup/restore, upgrade, change control, inventaire, scripts.

### Apps deployees

`argocd/apps/`:
- **argocd** — IngressRoute ArgoCD (l'installation est gérée par Terraform)
- **argo-rollouts** — progressive delivery
- **cert-manager** — wildcard `*.streamixs.com` via Cloudflare DNS01
- **cilium** — CNI + kube-proxy replacement + L2 announcements
- **cloudnative-pg** — operator Postgres (utilise par Immich et Securo)
- **external-services** — Services ClusterIP + EndpointSlice (Home Assistant, TrueNAS, Pocket-ID)
- **hermes** — agent Hermes (Nous Research), gateway Telegram en long polling, modele servi par la VM Ollama
- **immich** — galerie photo, backed par CloudNativePG
- **intel-gpu-plugin** — device plugin i915 pour Plex
- **longhorn** — storage replique pour les PVC RWO (configs des apps)
- **media** — stack media (voir ci-dessous)
- **monitoring** — kube-prometheus-stack, Loki, Promtail
- **securo** — gestionnaire de finances auto-hébergé, backed par CloudNativePG
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
- **autobrr** — automation de releases

### Storage

NFS statique via **TrueNAS** (192.168.1.10) :
```
/mnt/data/media    → media-pv (9 Ti, RWX)
/mnt/data/photos   → immich-library-pv (2 Ti, RWX)
```

Les PVC de config des apps utilisent `longhorn` (RWO, 2 réplicas sur les workers).
Il n'y a plus de democratic-csi dans le repo.

### Secrets Management

SOPS + Age encryption. La cle age est dans `.config/age.agekey` (gitignored).
KSOPS est injecte dans le repoServer ArgoCD via init container (config dans `terraform/resources/argocd/argocd-values.yaml`).
Convention : fichiers chiffres en `.sops.yaml`.

### Auth

La plupart des UI sensibles (Sonarr, Radarr, Prowlarr, qBittorrent, Grafana,
Prometheus, Alertmanager, etc.) passent par le middleware Traefik `forward-auth`
(namespace `auth`) qui delegue a **Pocket-ID** (OIDC).

Exceptions assumées :
- ArgoCD n'est pas encore derrière `forward-auth` ni OIDC : accès par compte
  admin local (à traiter).
- Immich, Home Assistant, Plex, Securo et Hermes ont leur propre auth/OIDC.
- Pocket-ID est externe au cluster (`192.168.1.4`).

### Adding a New Application

1. Creer `argocd/apps/<app-name>/kustomization.yaml` (l'ApplicationSet le decouvre automatiquement).
2. Si l'app utilise un nouveau repo Helm/OCI, l'ajouter dans `argocd/projects/platform.yaml` `sourceRepos`.
3. Si l'app a besoin de manifests custom, creer une base dans `argocd/base/<app-name>/`.
4. Si secret, utiliser SOPS + KSOPS generator (`generators/secret-generator.yaml`).
5. Verifier le namespace de destination, les probes, resources, securityContext, PSS et NetworkPolicy.
6. Epingler l'image et verifier que Renovate la suit (ou ajouter un custom manager).

### Key Config Details

- ArgoCD : branche cible `main`
- Kubeconfig prod : `~/.talos/kubeconfig-prod`
- State Terraform local pour l'instant : voir `terraform/STATE.md`
- Tous les ingresses utilisent le wildcard `*.streamixs.com` (cert-manager + Cloudflare DNS01)
- Talos : `v1.12.6`, Kubernetes : `v1.35.3`
- YAML style : 2-space indent, max 140 char lines, no document-start markers
- Documentation : `docs/`, en français

## CI

GitHub Actions :
- `validate-manifests.yml` : `yamllint` + `SOPS check`
- `validate-kustomize.yml` : rendu de toutes les apps, KSOPS inclus,
  `kubeconform` avec schémas CRD, job agrégé `all-kustomize`
- `validate-terraform.yml` : `terraform fmt/init/validate`
- `secret-scan.yml` : detection de secrets en clair

Limites restantes : Pluto, `actionlint`/`shellcheck`, validation Talos, test
d'admission kind/k3d, branch protection encore à activer. Voir
`docs/testing.md` et `TODO.md`.

Config yamllint dans `.yamllint.yaml`. Le fichier `argocd/base/cert-manager/issuers/secret-cf-token.yaml` est exclu (SOPS-encrypted).

## Documents associes

- `README.md` — Quickstart utilisateur
- `docs/bootstrap-prod.md` — Bootstrap prod détaillé
- `docs/testing.md` — Validation avant merge + lab jetable
- `docs/backup-restore.md` — Backups et restore
- `docs/upgrade-runbook.md` — Upgrades Talos/K8s/Cilium/Longhorn/CNPG
- `docs/change-control.md` — PR, squash, sync manuelle
- `docs/inventory.md` — Nœuds, IPs, domaines, ports
- `docs/scripts.md` — Rotation ArgoCD/SOPS
- `TODO.md` — Backlog priorisé
- `ROADMAP.md` — Vision et phases
