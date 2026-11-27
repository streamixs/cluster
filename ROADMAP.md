# Roadmap & Retrospective

> Revue 2026-11-27 — passage à un seul environnement permanent.

## Décision

Le cluster `dev` Docker est abandonné. Il ne permettait pas de reproduire la
stack prod (Talos, Cilium L2, Longhorn, GPU, NFS, données réelles) et il créait
un risque de toucher aux données de prod.

La cible est :

```
Prod (Talos bare metal)  — seul cluster permanent
CI (GitHub Actions)      — validation avant merge
Lab (kind/k3d)           — jetable, à la demande
Backups + restore        — filet de sécurité
```

Pas de staging permanent, pas de second ArgoCD, pas de données de prod dans un
cluster de test.

## Ce qui fonctionne bien

- **GitOps** : Talos + Cilium + ArgoCD ApplicationSet, auto-discovery des apps.
- **Un seul environnement** : moins de maintenance, moins de risques.
- **Secrets** : SOPS + Age + KSOPS, secret-scan en CI.
- **Auth centralisée** : Pocket-ID + traefik-forward-auth sur la majorité des UI.
- **Observabilité** : Prometheus, Grafana, Loki, Promtail, Alertmanager.
- **Stockage** : Longhorn pour les PVC RWO, NFS TrueNAS pour les médias/photos.
- **Réseau** : Cilium kube-proxy replacement, L2 announcements, IP pool.
- **Upgrades** : `etcd-backup`, `k8s-upgrade-check`, `talos-upgrade-check`.

## Risques critiques restants

### 1. Aucun backup

Pas de backup CNPG, Longhorn, etcd automatisé, ni de copie offline de la clé
age. C'est le risque numéro un pour Immich, Securo, Hermes et les configs.

### 2. ArgoCD et l'auth trop exposés

ArgoCD n'a ni OIDC ni forward-auth, l'AppProject est quasi cluster-admin, le
repo-server détient la clé age et exécute des plugins, et `traefik-forward-auth`
tourne en un seul replica sans probe.

### 3. Segmentation réseau insuffisante

NetworkPolicies uniquement sur Securo et Hermes. Media, Immich, ArgoCD, auth,
monitoring et external-services ne sont pas cloisonnés.

### 4. CI incomplète

Les apps KSOPS sont sautées, donc `media` en entier n'est pas validée. Les CRDs
ne sont pas validées, Terraform/Talos ne sont pas validés, et la version K8s de
la CI est en retard.

## Plan d'amélioration

### Phase 1 — Finaliser la suppression du dev

- [x] Supprimer `talos/dev/`.
- [x] Makefile prod-only, `make gitops`.
- [x] Terraform par défaut sur `kubeconfig-prod`.
- [x] Labels ArgoCD `env: prod`.
- [x] Documentation alignée sur un seul environnement.
- [x] Runbooks dans `docs/`.
- [ ] Nettoyer les ressources runtime dev (cluster Docker, kubeconfig, state).
- [ ] La branche `develop` n'est plus utilisée ; sa suppression remote est laissée
      à ta main (pas de suppression automatique).

### Phase 2 — CI de validation complète

- [ ] Rendre toutes les apps, y compris KSOPS.
- [ ] Kubeconform avec schémas CRD.
- [ ] Pluto.
- [ ] Terraform fmt/validate.
- [ ] Actionlint, shellcheck, renovate-config-validator.
- [ ] Actions GitHub épinglées par SHA.
- [ ] Job CI agrégé `all-validations`.
- [ ] Branch protection sur `main` (PR + checks requis + squash only + pas de
      force push).
- [ ] `make validate` local.
- [ ] Auto-merge Renovate désactivé et merges manuels documentés.

### Phase 3 — Backups et restore

- [ ] CNPG → MinIO/S3.
- [ ] Longhorn backup target + RecurringJob.
- [ ] etcd snapshot automatisé + chiffré + hors cluster.
- [ ] Snapshots ZFS/réplication TrueNAS.
- [ ] Clé age offline.
- [ ] Test de restore documenté.

### Phase 4 — Change control

- [ ] Sync manuelle ou sync windows pour l'infra.
- [ ] `Prune=false` sur CRDs/PVC/Clusters CNPG.
- [ ] Retirer le hook PreDelete Longhorn.
- [ ] Sync waves.
- [ ] Notifications ArgoCD.

### Phase 5 — Robustesse

- [ ] Probes, PDB, resources, priorityClass.
- [ ] Anti-affinité Traefik/forward-auth.
- [ ] NetworkPolicies et PSS.
- [ ] Découper l'app media.
- [ ] Renovate : `minimumReleaseAge`, managers manquants.

### Phase 6 — Exploitation

- [x] Runbooks bootstrap/testing/upgrade/backup/change-control/inventaire.
- [ ] Décision 1 CP vs 3 CP, RTO/RPO.
- [ ] Chiffrement des disques Talos.
- [ ] ExternalDNS, Gatus, Crowdsec.
- [ ] Promtail → Grafana Alloy.

## Non-objectifs

- Maintenir un cluster `dev` ou `staging` permanent.
- Reproduire la stack prod à l'identique sur un laptop.
- Tester les données réelles dans un cluster de test.
- Déployer automatiquement les composants d'infrastructure sans revue.

## Règle de merge (cible)

- `main` protégée par un ruleset.
- Toute modification passe par une PR.
- Squash-merge uniquement.
- Checks CI obligatoires.
- Pas d'auto-merge : merge manuel après validation.
- Les composants d'infrastructure se synchronisent manuellement, avec backup
  et plan de rollback.

L'état exact des réglages GitHub et la procédure sont dans
`docs/change-control.md`.
