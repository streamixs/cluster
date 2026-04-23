# Terraform State Management

## Current setup (local state — dev/bootstrap only)

The Terraform state is stored **locally** in `terraform.tfstate`. This file is gitignored and must **never** be committed.

The state contains sensitive data in plaintext:
- ArgoCD admin password (retrieved from the `argocd-initial-admin-secret` K8s secret)
- SOPS age private key (loaded from `.config/age.agekey` into the `sops-age` K8s secret)

## Why local state is acceptable here

This Terraform code is a **one-shot bootstrap** tool. It runs once to install ArgoCD into a fresh cluster. After bootstrap, cluster state is managed entirely by ArgoCD/GitOps. Terraform is not used for day-to-day operations.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| State file shared accidentally | Gitleaks CI blocks commits; `.gitignore` excludes `*.tfstate` |
| State file lost | Re-running `terraform apply` recreates resources (ArgoCD is idempotent) |
| Secrets in plaintext state | Rotate after bootstrap: see `scripts/rotate-argocd-password.sh` and `scripts/rotate-sops-key.sh` |

## Migration to remote backend (tracked in separate issue)

When Terraform manages more resources, migrate to a remote backend with encryption at rest (e.g., Terraform Cloud, S3 + KMS, or GitLab-managed state).

Template for S3 backend (add to `main.tf`):
```hcl
terraform {
  backend "s3" {
    bucket         = "streamixs-tfstate"
    key            = "cluster/terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    kms_key_id     = "alias/terraform-state"
    dynamodb_table = "streamixs-tfstate-lock"
  }
}
```
