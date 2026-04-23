# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kubernetes cluster infrastructure managed via GitOps. Talos Linux as OS, Cilium as CNI, ArgoCD for continuous delivery. Two environments: **dev** (Docker-based) and **prod** (bare metal mini PCs).

## Common Commands

```bash
# Bootstrap full cluster (dev)
make bootstrap                    # creates Talos cluster + deploys ArgoCD

# Bootstrap full cluster (prod)
make bootstrap ENV=prod           # creates Talos cluster + Cilium + ArgoCD

# Cluster status
make status                       # nodes + all pods
make status ENV=prod

# Talos config generation (prod)
make talos-gen-secret ENV=prod    # generate + encrypt Talos secrets
make talos-gen ENV=prod           # generate machine configs with talhelper

# ArgoCD management
make argocd                       # deploy ArgoCD via Terraform
make destroy-argocd               # remove ArgoCD via Terraform

# Terraform (run from terraform/)
cd terraform && terraform init
cd terraform && terraform apply -var="kubeconfig=~/.talos/kubeconfig-dev"

# YAML linting (runs in CI on PRs)
yamllint -c .yamllint.yaml .

# Teardown dev only
make destroy
```

## Architecture

### GitOps Flow

ArgoCD uses an **ApplicationSet** (`argocd/bootstrap/app-of-apps.yaml`) that auto-discovers applications by scanning `argocd/apps/*` directories. Each subdirectory becomes an ArgoCD Application automatically. The namespace defaults to the directory name.

### Directory Conventions

- **`argocd/apps/<app-name>/`** — Each directory is auto-discovered as an ArgoCD Application. Contains either a `kustomization.yaml` (for Kustomize apps) or Helm chart reference. Adding a new directory here is sufficient to deploy a new app.
- **`argocd/base/`** — Kustomize bases referenced by apps. Shared manifests (Deployments, Services, PVCs) live here.
- **`argocd/bootstrap/`** — The ApplicationSet and AppProject definitions. Rarely modified.
- **`argocd/projects/`** — ArgoCD AppProject definitions. New Helm repos must be added to `platform.yaml`'s `sourceRepos`.
- **`talos/dev/` and `talos/prod/`** — Talos machine configs via `talhelper`. Generated configs go to `clusterconfig/` (gitignored).
- **`terraform/`** — Only handles ArgoCD Helm install + SOPS age key secret. Not used for other apps.

### Secrets Management

SOPS + Age encryption. The age key lives at `.config/age.agekey` (gitignored). KSOPS is injected into ArgoCD's repoServer as an init container (configured in `terraform/resources/argocd/argocd-values.yaml`). Encrypted files use the `.sops.yaml` suffix convention.

### Adding a New Application

1. Create `argocd/apps/<app-name>/kustomization.yaml` (the ApplicationSet discovers it automatically)
2. If the app uses a new Helm repo, add it to `argocd/projects/platform.yaml` `sourceRepos`
3. If the app needs custom manifests, create a base in `argocd/base/<app-name>/`

### Key Config Details

- ArgoCD targets the `main` branch
- Dev kubeconfig: `~/.talos/kubeconfig-dev`, Prod: `~/.talos/kubeconfig-prod`
- All ingresses use `*.streamixs.com` wildcard cert via cert-manager + Cloudflare DNS01
- NFS provisioner points to `54.36.178.170:/export/k8s` (hardcoded)
- YAML style: 2-space indent, max 140 char lines, no document-start markers

## CI

GitHub Actions runs `yamllint` on PRs (`.github/workflows/validate-manifests.yml`). Config in `.yamllint.yaml`. The file `argocd/base/cert-manager/issuers/secret-cf-token.yaml` is excluded from linting (SOPS-encrypted).
