# TODO

> Revue 2026-11-28 — un seul environnement permanent : `prod`.
> Le lab de test est jetable (`kind`/`k3d`), jamais synchronisé avec la prod.

## P0 — Sécurité et données

- [ ] **Backups CNPG** : Immich et Securo vers MinIO/S3 (barmanObjectStore),
      rétention + test de restore.
- [ ] **Backups Longhorn** : backup target + RecurringJob pour les PVC de config,
      test de restore.
- [ ] **Backups etcd** : snapshot automatisé, chiffré, stocké hors cluster.
- [ ] **Clé age** : copie offline dans un gestionnaire de mots de passe.
- [ ] **Snapshots TrueNAS** : ZFS + réplication pour `/mnt/data/photos` et
      `/mnt/data/media`.
- [x] **Alertmanager** : receiver Telegram + Watchdog, token SOPS et `chat_id`
      renseignés, URLs publiques via `externalUrl`. Vérifié par alerte de test.
- [x] **Grafana** : `adminPassword: changeme` supprimé, Secret SOPS
      `grafana-admin`.
- [x] **Alertes monitoring** : certificats cert-manager, Longhorn, disque node
      et CNPG. Voir `docs/monitoring-alerting.md`.
- [x] **ArgoCD** : OIDC Pocket-ID + RBAC sur le groupe `admin`, admin local
      conservé en break-glass. Voir `docs/argocd-oidc.md`.
- [x] **Remplacer `traefik-forward-auth` par `oauth2-proxy`** : cutover global
      terminé. Voir `docs/oauth2-proxy-migration.md`.
- [x] **ArgoCD AppProject** : `destinations` et
      `clusterResourceWhitelist` explicites. Voir `argocd/README.md`.
- [ ] **NetworkPolicies** : media, immich, argocd, auth, monitoring,
      external-services. Securo et Hermes servent de modèle.
- [ ] **Pod Security Standards** : baseline sur tous les namespaces
      applicatifs, restricted là où c'est possible.
- [x] **SOPS check en CI** : vérifier que les secrets sont bien chiffrés.

## P1 — CI et pré-merge

- [x] **Rendre toutes les apps en CI**, y compris celles qui utilisent KSOPS
      (`media`, `cert-manager`, `hermes`, `securo`, `traefik-forward-auth`).
- [x] **Kubeconform + schémas CRD** (Traefik, Cilium, CNPG, Longhorn,
      cert-manager, monitoring). Certains CRDs restent `skipped` faute de
      schéma, mais les types core et la majorité des CRDs sont validés.
- [ ] **Pluto** pour les APIs dépréciées.
- [x] **Kubernetes version CI** : passée à `1.35.3`.
- [x] **Terraform CI** : `fmt -check`, `init -backend=false`, `validate`.
- [ ] **Actionlint + shellcheck + renovate-config-validator**.
- [ ] **Actions GitHub épinglées par SHA**.
- [x] **Branch protection `main`** : PR obligatoire, checks requis,
      branche à jour, pas de force push, squash only.
- [x] **Job CI agrégé** `all-kustomize` à exiger dans la protection.
- [ ] **`make validate`** : reproduire la CI en local.
- [ ] **PR template** : checklist validation, backup, rollback.
- [x] **Désactiver l'auto-merge Renovate** et documenter le merge manuel.
- [ ] **Sync manuelle / sync windows** pour Cilium, Longhorn, CNPG,
      cert-manager, Traefik.
- [ ] **Sync waves** : CNPG → Immich/Securo, cert-manager → Traefik,
      monitoring → ServiceMonitors.
- [ ] **`Prune=false`** sur les CRDs, PVC/PV, clusters CNPG.
- [ ] **Retirer le hook PreDelete Longhorn** ou le sécuriser.

## P2 — Robustesse

- [ ] Probes manquantes : sonarr, lidarr, prowlarr, tautulli, liveness Hermes.
- [ ] PDB : cert-manager, ArgoCD, CNPG, monitoring.
- [x] `oauth2-proxy` : 2 replicas + anti-affinité + NetworkPolicy + probes.
- [ ] `oauth2-proxy` : restreindre les emails (`email-domain`/`allowed-group`)
      au lieu de `*`.
- [ ] Traefik : anti-affinité required ou topologySpreadConstraints.
- [ ] Resources + priorityClass : Traefik, Cilium, cert-manager, ArgoCD,
      Longhorn.
- [ ] Longhorn : réactiver `preUpgradeChecker` ou documenter le contournement.
- [x] Traefik : chart `40.3.0` → `42.4.3` (Traefik `v3.7.20`), fait le
      2026-11-27. App en sync manuelle.
- [ ] Traefik `43.0.0` (Traefik 3.8.0) après une période de cooling.
- [x] Traefik ForwardAuth : `maxResponseBodySize: 1 MiB` ajouté (protection
      mémoire/DoS sur la réponse du serveur d'auth).
- [ ] Talos : retirer `vm.nr_hugepages: 1024` si inutile, ajouter les limites
      inotify pour Plex/*arr.
- [ ] Renovate : `minimumReleaseAge`, managers `imageName` et
      `intel-gpu-plugin`, politique charts vs images.
- [ ] Découper l'app `media` en plusieurs Applications et factoriser
      qbittorrent/qbittorrent-seed.
- [ ] `argocd` : notifications ArgoCD.
- [ ] `argocd` : corriger les namespaces vides créés par `destination.namespace`.
- [ ] Vérifier `CiliumLoadBalancerIPPool` / `CiliumL2AnnouncementPolicy` :
      Kustomize ajoute un namespace à des ressources cluster-scoped.

## P3 — Exploitation et documentation

- [x] Mettre à jour `PRIVACY.md` pour Ollama Cloud, en gardant le fichier à la
      racine (URL Google OAuth).
- [ ] Supprimer `scripts/hermes-migrate-pod.yaml` (migration terminée).
- [ ] Renommer l'Application ArgoCD `traefik-forward-auth` en `oauth2-proxy`
      (garder le cutover séparé du renommage).
- [ ] Décider 1 CP + backup/restore ou 3 CP ; documenter le RTO/RPO.
- [ ] Chiffrement des disques Talos (LUKS2/TPM) pour les données au repos.
- [ ] ExternalDNS + Cloudflare, Gatus, Crowdsec/rate limiting Traefik.
- [ ] Migration Promtail → Grafana Alloy.
- [ ] State Terraform : garder local + backup pour l'instant ; étudier un
      backend chiffré plus tard.
- [ ] Politique de release des bumps Renovate (fix(deps) vs chore(deps)) —
      décision reportée.

## Fait

- [x] Monitoring : kube-prometheus-stack + Loki + Promtail.
- [x] Renovate Bot (merges manuels, pas d'auto-merge).
- [x] Ruleset `main` actif : PR + checks requis + squash only + pas de force push.
- [x] Auth : `traefik-forward-auth` remplacé par `oauth2-proxy` (2 replicas,
      PDB, probes, NetworkPolicy).
- [x] CI : rendu de toutes les apps (KSOPS inclus), kubeconform + schémas CRD,
      Terraform, SOPS check, job agrégé `all-kustomize`.
- [x] Images épinglées (sauf quelques cas suivis).
- [x] SOPS + Age + KSOPS + gitleaks.
- [x] Traefik 2 replicas + PDB, Cilium L2 + IP pool.
- [x] NetworkPolicies Securo et Hermes.
- [x] Suppression de l'environnement dev dans le code (Makefile, docs, `talos/dev/`).
- [x] `.gitignore` : `backups/` et `*.snapshot`.
- [x] `.yamllint.yaml` : chemins obsolètes retirés.
- [x] Docs : bootstrap, testing, backup/restore, upgrade, change control,
      inventaire, scripts.
