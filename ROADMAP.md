# Roadmap & Retrospective

> Revue du 2026-05-15

Etat des lieux du cluster et plan d'amelioration. Pour les actions tres ponctuelles, voir `TODO.md`.

## Ce qui fonctionne bien

- **GitOps clean** : Talos + Cilium + ArgoCD ApplicationSet, auto-discovery des apps
- **Sep dev/prod** : Docker local + bare-metal, Makefile factorise
- **Secrets** : SOPS + Age + KSOPS, secret-scan en CI
- **Auth centralisee** : Pocket-ID + traefik-forward-auth sur ingresses sensibles
- **Upgrades** : `make k8s-upgrade-check` + `etcd-backup` avant action
- **Storage** : migration NFS hardcode -> democratic-csi + TrueNAS

## Defauts critiques (a traiter en priorite)

### 1. Aucun monitoring
Pas de Prometheus, Grafana, Loki, Alertmanager. Cluster 4 nodes en prod sans observabilite.
Action : deployer `kube-prometheus-stack` + `loki-stack` + `promtail`.

### 2. Aucun backup
- Pas de Velero
- Pas de snapshot automatique des PV Longhorn
- Pas de backup CNPG
- Seul `etcd-backup` manuel via Makefile
Action : Velero + S3 (MinIO sur TrueNAS) + verif crons.

### 3. App-of-apps pointe sur branche feature
`argocd/bootstrap/app-of-apps.yaml` : `revision: feat/media-music-stack`.
Le TODO disait pourtant "develop -> main". A fixer immediatement.

### 4. Tags d'images flottants
- `ghcr.io/autobrr/qui:latest` (critique)
- `thomseddon/traefik-forward-auth:2` (mineur)

### 5. Probes manquantes
Manque liveness/readiness sur : `prowlarr`, `sonarr`, `lidarr`, `tautulli`, `traefik-forward-auth`.

### 6. SecurityContext incomplet
Seulement `fsGroup` au pod level. Manque partout :
```yaml
runAsNonRoot: true
allowPrivilegeEscalation: false
capabilities: { drop: [ALL] }
seccompProfile: { type: RuntimeDefault }
```

### 7. Control-plane non-HA en prod
1 seul CP + `allowSchedulingOnControlPlanes: false` = SPOF + ressources gaspillees.
Options : passer a 3 CP, ou autoriser le scheduling sur le CP unique.

### 8. NetworkPolicies = 0
Cilium installe mais aucune segmentation. Un pod compromis peut taper partout.

## Incoherences a corriger

| Endroit | Probleme |
|---|---|
| `app-of-apps.yaml` L43-44 | `--enable-helm` et `--load-restrictor` sont des flags kustomize CLI, pas des syncOptions ArgoCD valides |
| Cilium values | `l2announcements.enabled: true` mais aucun `CiliumL2AnnouncementPolicy` / `CiliumLoadBalancerIPPool` dans le repo |
| Hubble | UI activee dans values mais pas d'IngressRoute -> inaccessible |
| Versions K8s | dev v1.35.0 vs prod v1.35.3 |
| Resources | qbittorrent : `limits.memory` sans `limits.cpu`. Sonarr : les deux. Pas de standard |

## A ajouter (par ROI decroissant)

### Priorite haute
1. **Stack monitoring** : kube-prometheus-stack + loki-stack + promtail
2. **Renovate Bot** : auto-PR pour images + Helm charts (auto-merge patches)
3. **CI validation** : `kustomize build` + `kubeconform` sur chaque app
4. **Velero** + S3 (MinIO TrueNAS) pour backup manifests + PV snapshots
5. **NetworkPolicies de base** : deny-all par namespace + allow explicit

### Priorite moyenne
6. **Homepage / Homer** : dashboard liens vers toutes les UI
7. **Kustomize overlays dev/prod** (deja dans TODO P4)
8. **External-DNS + Cloudflare** : auto-creer les records `*.streamixs.com`
9. **ArgoCD sync waves** : ordonner cert-manager -> traefik -> reste
10. **Notifications Discord/Slack** ArgoCD

### Nice-to-have
11. Pocket-ID en HA (replicas: 2)
12. Gatus pour monitoring externe public
13. Tailscale operator pour acces hors LAN
14. Crowdsec pour traefik

## Ameliorations structurelles

- **Factoriser qbittorrent + qbittorrent-seed** : une seule base parametree via Kustomize overlays (instance, port BT, subPath)
- **"common" patch Kustomize** : securityContext, resources, probes appliques via `patches:` global
- **Decouper `argocd/apps/media/`** : 12 apps deviennent lourdes. ApplicationSet imbrique par categorie (downloaders, *arr, ui)
- **Standardiser les Helm values** : tous dans `apps/*/values.yaml` (cert-manager pas encore aligne)

## Top 5 actions immediates

1. Fixer `app-of-apps.yaml` -> `revision: main`
2. Deployer kube-prometheus-stack
3. Pin `qui:latest` -> version concrete
4. Renovate Bot
5. Strategie de backup (Velero ou cron Longhorn snapshots minimum)
