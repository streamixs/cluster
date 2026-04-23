# TODO

> Review 2026-03-25

## P0 — Securite

- [x] ~~Auth sur les ingress media~~ — Pocket-ID + traefik-forward-auth (PR #69)
- [x] Fixer les tags d'images containers (CRITIQUE)
  - [x] qbittorrent : `:latest` → version fixe (ex: `release-5.0.4`)
  - [x] sonarr : `:release` → version fixe (ex: `release-4.0.14.2939`)
  - [x] radarr : `:release` → version fixe (ex: `release-5.22.4.9896`)
  - [x] prowlarr : `:release` → version fixe (ex: `release-1.33.3.5048`)
  - [x] pocket-id : `:v2` → version fixe (ex: `v2.4.0`)
  - [-] traefik-forward-auth : `:2` → version fixe (ex: `2.2.0`)
- [ ] SecurityContext container-level sur tous les deployments
  - [ ] pocket-id : aucun securityContext defini
  - [ ] radarr, sonarr, prowlarr, qbittorrent : seulement fsGroup, manque `runAsNonRoot`, `allowPrivilegeEscalation: false`, `capabilities.drop`
- [ ] NetworkPolicies : deny-all + allow-specific par namespace (Cilium)
- [ ] SOPS check en CI : empecher les commits de secrets en clair
- [ ] Gitleaks en CI : scanner les diffs pour tokens/cles API

## P1 — CI / Automatisation

### Phase 1 — Validation (prioritaire)

- [ ] Kustomize build : `kustomize build` sur chaque app pour valider les refs et la structure
- [ ] Kubeconform : validation des manifests contre les schemas K8s (champs invalides, types, CRDs)
- [ ] Helm template : valider que les values produisent des manifests valides

### Phase 2 — Versions et securite images

- [ ] Renovate Bot : auto-PR pour charts Helm et images Docker
- [ ] Renovate auto-merge : merge automatique des patches (ex: v2.4.0 → v2.4.1) apres CI verte
- [ ] Trivy : scan CVE des images containers referencees dans les manifests

### Phase 3 — Deploiement et visibilite

- [ ] Checkov / Kubesec : audit securite des manifests K8s
- [ ] ArgoCD diff preview : commenter les PRs avec le diff ArgoCD
- [ ] Notifications Discord/Slack : alerter quand ArgoCD sync ou fail

## P2 — Robustesse

- [ ] Health checks manquants
  - [ ] sonarr : aucun livenessProbe / readinessProbe
  - [ ] prowlarr : aucun livenessProbe / readinessProbe
  - [ ] traefik-forward-auth : aucun probe (ajouter tcpSocket:4181)
- [ ] PodDisruptionBudgets : definir des PDB pour les services critiques (auth, media)
- [ ] Replicas : augmenter pocket-id et traefik-forward-auth a 2 replicas (prod)
- [ ] Resource limits Helm charts : definir les resources dans les values (traefik, cert-manager, monitoring, loki, cilium)

## P3 — Amelioration

- [x] ArgoCD targetRevision : passer de `develop` a `main`
- [ ] Grafana persistence : PVC pour dashboards
- [x] ~~NFS IP en variable~~ — remplace par democratic-csi + TrueNAS
- [x] ~~Evaluer Cilium IngressController pour remplacer ingress-nginx~~ — migre vers Traefik (PR #67)

## P4 — Prod ready

- [ ] Certificat Let's Encrypt production (remplacer staging)
- [ ] Promotion dev → prod : workflow PR de promotion apres validation en dev
- [ ] Backup verification : cron pour verifier les backups CNPG + PV snapshots
- [ ] Uptime monitoring : healthcheck externe (UptimeRobot, Gatus)
- [ ] Kustomize overlays dev/prod pour les valeurs specifiques a l'environnement
