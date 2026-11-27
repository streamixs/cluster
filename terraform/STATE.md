# Terraform State Management

## Current setup (local state — prod bootstrap only)

The Terraform state is stored **locally** in `terraform.tfstate`. This file is gitignored and must **never** be committed. It now targets the single permanent `prod` cluster; there is no `dev` environment.

The state contains sensitive data in plaintext:
- ArgoCD admin password (retrieved from the `argocd-initial-admin-secret` K8s secret)
- SOPS age private key (loaded from `.config/age.agekey` into the `sops-age` K8s secret)

## Why local state is acceptable here

This Terraform code is a **one-shot bootstrap** tool. It runs once to install ArgoCD into the prod cluster. After bootstrap, cluster state is managed entirely by ArgoCD/GitOps. Terraform is not used for day-to-day operations.

Avant toute suppression ou migration du state, vérifier qu'il cible bien le
cluster prod (`terraform state list`, `terraform plan`) et en faire une copie
de sauvegarde.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| State file shared accidentally | Gitleaks CI blocks commits; `.gitignore` excludes `*.tfstate` |
| State file lost | Garder une copie de sauvegarde ; `terraform apply` peut recréer ArgoCD **si** `.config/age.agekey` existe encore |
| Secrets in plaintext state | Sauvegarder le state hors ligne ; faire tourner les secrets après bootstrap via `scripts/rotate-argocd-password.sh` et `scripts/rotate-sops-key.sh` |
| Lock file non versionné | `.terraform.lock.hcl` est commité (hashes linux_amd64 + darwin_arm64) |

## Décision actuelle : state local

Le state reste **local** pour l'instant, avec sauvegarde. C'est un choix assumé
pour un bootstrap one-shot, mais il contient la clé age et le mot de passe admin
en clair. Ne jamais le commiter, ne jamais le partager.

## Migration future vers un backend distant

À étudier plus tard, sans urgence :

- S3/MinIO + chiffrement au repos,
- Terraform Cloud ou GitLab-managed state,
- backend avec locking natif (`use_lockfile = true` sur Terraform récent).

Template indicatif (à adapter, non actif) :
```hcl
terraform {
  backend "s3" {
    bucket       = "streamixs-tfstate"
    key          = "cluster/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    kms_key_id   = "alias/terraform-state"
    use_lockfile = true
  }
}
```
