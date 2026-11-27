# Change control

## Principes

- Un seul environnement permanent : `prod`.
- Aucune modification directe sur `main`.
- Toute modification passe par une branche + PR.
- Merge uniquement en **squash**.
- Merge manuel après validation : pas d'auto-merge.
- Les composants d'infrastructure se synchronisent manuellement ou dans une
  sync window, avec backup et rollback.

## État GitHub actuel

À la date de rédaction :

- `allow_merge_commit: false`
- `allow_rebase_merge: false`
- `allow_squash_merge: true`
- titre de squash : `PR_TITLE`
- message de squash : `PR_BODY`
- `allow_auto_merge: false`
- les branches ne sont pas supprimées après merge (choix assumé)
- `main` n'est pas encore protégée par un ruleset actif

Cible (après merge de la PR CI qui ajoute `all-kustomize`) :

- ruleset actif sur `main`,
- PR obligatoire,
- checks requis : `YAML lint`, `SOPS check`, `Detect secrets`,
  `all-kustomize`, `Terraform validate`,
- pas de force push ni suppression,
- historique linéaire,
- squash avec titre de PR.

## Apps à risque

Sync manuelle ou sync window recommandée :

- `cilium`
- `longhorn`
- `cloudnative-pg`
- `cert-manager`
- `traefik`
- `securo`
- `immich`

Les apps media peuvent rester en auto-sync si les probes et backups sont en
place.

## Ressources à données

À protéger avec `argocd.argoproj.io/sync-options: Prune=false` :

- CRDs,
- PVC/PV,
- `Cluster` CNPG,
- ressources Longhorn critiques.

Ne jamais laisser ArgoCD pruner un CRD ou un PVC sans revue explicite.

## Checklist PR

- [ ] Titre de PR conventionnel (`feat:`, `fix:`, `chore:`...).
- [ ] `yamllint` passe.
- [ ] `kustomize build` passe pour les apps modifiées.
- [ ] `terraform fmt/validate` si `terraform/` est modifié.
- [ ] Secrets SOPS uniquement.
- [ ] Images épinglées.
- [ ] Diff ArgoCD relu pour l'infra.
- [ ] Backup pris si risqué.
- [ ] Plan de rollback écrit.
- [ ] Label `risk/high` / `needs-backup` / `needs-manual-sync` si applicable.

## Urgence

Si une app est cassée en prod :

1. Couper l'auto-sync de l'app concernée (si elle est en auto-sync).
2. Sauvegarder l'état utile (logs, événements, snapshot si possible).
3. Corriger via PR ou revert Git.
4. Remettre l'auto-sync après stabilisation.
5. Documenter l'incident.

## Releases

`release-please` maintient une Release PR. La politique de release des bumps
Renovate n'est pas encore tranchée : `fix(deps)` crée une release, `chore(deps)`
la masque. Ne pas changer cette politique sans décision explicite.
