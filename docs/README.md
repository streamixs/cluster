Media automation stack on Kubernetes (streamixs.com)

### Vue d'ensemble de l'architecture
- **Namespaces**
  - `media`: applications médias (Sonarr/Radarr/Lidarr/Readarr, Prowlarr, qBittorrent+Gluetun, Bazarr, Jellyfin/Plex, Overseerr, Recyclarr, Tautulli)
  - `ingress-nginx`, `cert-manager`, `infra` (external-dns), `monitoring` (Prometheus/Grafana), `logging` (Loki/Promtail), `velero`, `storage` (NFS provisioner)
- **Entrée**: Ingress NGINX avec TLS via cert-manager (ClusterIssuer `letsencrypt-prod`) et external-dns (Cloudflare)
- **Réseau**: NetworkPolicies par défaut en deny, allow uniquement depuis `ingress-nginx` et entre services nécessaires; DNS egress autorisé. qBittorrent sort uniquement via Gluetun (VPN)
- **Stockage**: 
  - RWX partagé via NFS dynamique `nas-rwx` (nfs-subdir-external-provisioner) pour `/downloads` et `/media`
  - RWO (classe par défaut du cluster) pour `/config`
- **Observabilité**: kube-prometheus-stack (Prometheus, Alertmanager, Grafana), ServiceMonitors activés + Blackbox exporter, Loki/Promtail pour logs
- **Sauvegardes**: Velero + Restic (sauvegardes quotidiennes des PVC de `media`)

Flux haut-niveau
- Internet → Ingress NGINX → services HTTP médias avec TLS (Let's Encrypt)
- Apps ARR ↔ qBittorrent (HTTP API) ↔ téléchargements → `/downloads` (NFS RWX)
- Post-traitement vers `/media` (NFS RWX). Jellyfin/Plex lisent `/media`
- qBittorrent → egress Internet via sidecar Gluetun (VPN). Egress direct bloqué

### Prérequis
- Kubernetes >=1.27, accès admin kubectl
- Domaine public: `streamixs.com` et email ACME: `louis.sasse@protonmail.com`
- DNS provider: Cloudflare (token API scellé)
- Connectivité site-to-site entre nœuds du cluster et NAS (WireGuard/IPsec)
- Exports NFS sur le NAS: `/export/k8s` (provisioner), optionnellement `/export/media` et `/export/downloads`
- S3 compatible pour Velero
- PUID/PGID alignés avec les permissions du NAS

### Placeholders à renseigner
- `<NAS_VPN_IP>` dans `values/infra/nfs-provisioner.yaml`
- `<PUID>`, `<PGID>` dans `values/media/globals.yaml` et apps
- `<S3_BUCKET_NAME>`, `<S3_REGION>`, `<S3_ENDPOINT_URL>`, `<S3_ACCESS_KEY_ID>`, `<S3_SECRET_ACCESS_KEY>` dans `values/infra/velero.yaml`
- `<VPN_PROVIDER>` et variables Gluetun dans le Secret scellé `gluetun-vpn-secret`
- `<GIT_REPO_URL>` dans `argocd/applications.yaml` (si GitOps)

### Déploiement pas-à-pas
1) Secrets (Cloudflare & Gluetun) via SealedSecrets
```bash
kubectl -n infra create secret generic cloudflare-api-token --from-literal=api-token=<CLOUDFLARE_TOKEN>
kubeseal -n infra -o yaml <(kubectl -n infra get secret cloudflare-api-token -o yaml) > secrets/cloudflare-api-token.sealed.yaml

kubectl -n media create secret generic gluetun-vpn-secret \
  --from-literal=VPN_SERVICE_PROVIDER=<wireguard|openvpn> \
  --from-literal=WIREGUARD_PRIVATE_KEY=<...> \
  --from-literal=WIREGUARD_ADDRESSES=<10.13.13.2/32> \
  --from-literal=OPENVPN_USER=<...> \
  --from-literal=OPENVPN_PASSWORD=<...>
kubeseal -n media -o yaml <(kubectl -n media get secret gluetun-vpn-secret -o yaml) > secrets/gluetun-vpn-secret.sealed.yaml
```

2) Namespace & ClusterIssuer
```bash
kubectl apply -f namespace/media-namespace.yaml
kubectl apply -f ingress/cluster-issuer.yaml
```

3) Vérifier la connectivité NAS
- Tunnel site-to-site UP, routes en place
```bash
# depuis un nœud (ou DaemonSet toolbox)
showmount -e <NAS_VPN_IP>
mount -t nfs -o vers=4.1 <NAS_VPN_IP>:/export/k8s /mnt && umount /mnt
```

4) Installer l'infra (Ingress, DNS, Monitoring, Logging, Backups, NFS)
```bash
make bootstrap        # ajoute repos + ClusterIssuer
make apply-infra
```
Contrôles rapides:
```bash
kubectl -n cert-manager get clusterissuer
kubectl -n ingress-nginx get pods
kubectl -n infra get deploy external-dns
kubectl -n storage get deploy nfs-subdir-external-provisioner
kubectl -n monitoring get pods
kubectl -n logging get pods
kubectl -n velero get pods
```

5) Déployer la stack média
```bash
make apply-media
```
Validation:
```bash
kubectl -n media get pods,svc,ingress,pvc
dig +short sonarr.streamixs.com
```

6) Post-configuration
- Prowlarr: ajouter vos indexers
- Sonarr/Radarr/Lidarr/Readarr: client qBittorrent, catégories, chemins `/downloads` et `/media`
- Overseerr: liaison Jellyfin/Plex, notifications

### GitOps (optionnel)
```bash
# Après mise à jour de <GIT_REPO_URL>
kubectl -n argocd apply -f argocd/appproject.yaml
kubectl -n argocd apply -f argocd/applications.yaml
```

### Observabilité
- Grafana: `grafana.streamixs.com` (TLS), dashboards K8s/Applications
- Prometheus: ServiceMonitors apps + probes Blackbox (job `blackbox-media-https`)
- Alertes: `observability/prometheus-rules.yaml` (apps down, probes KO). Configurer Alertmanager receivers
- Logs: Loki+Promtail (namespace `logging`)

### Sauvegardes Velero
- Configuration S3 dans `values/infra/velero.yaml`
- Sauvegardes planifiées quotidiennes pour namespace `media`
```bash
kubectl -n velero get backupstoragelocations
kubectl -n velero get schedules,backups
velero backup create media-manual --include-namespaces media
```

### Sécurité
- Pod Security: `runAsNonRoot`, `readOnlyRootFilesystem` (si possible), `seccompProfile: RuntimeDefault`, `fsGroup` (aligner avec `<PGID>`)
- Capabilities: drop `ALL`; Gluetun ajoute uniquement `NET_ADMIN`
- NetworkPolicies: deny par défaut; autoriser ingress depuis `ingress-nginx`; DNS egress; qBittorrent egress restreint via `networkpolicies/qbittorrent-vpn-egress.yaml`
- Secrets: SealedSecrets

### Stockage
- `nas-rwx` (RWX) pour `/downloads` et `/media` (NFS dynamique). Reste en RWO (`/config`)
- Si besoin de PV statiques, créer PV/PVC dédiés et utiliser `existingClaim` dans les valeurs des apps

### Dépannage rapide
- Certificats: `kubectl -n cert-manager describe certificate` et `challenge`
- DNS: vérifier ExternalDNS logs, `dig +short <app>.streamixs.com`
- Réseau: `kubectl -n media get netpol`; tester connectivité entre pods avec une BusyBox
- VPN: vérifier liveness/readiness du conteneur Gluetun et que le trafic direct est bloqué (policy egress)
- NFS: events des pods, logs du provisioner `storage/…`, montages NFS sur nœuds
- Probes: `kubectl -n media describe pod <name>` → liveness/readiness

### Commandes utiles
```bash
make diff
make status
helmfile -f helmfiles/infra/helmfile.yaml lint
helmfile -f helmfiles/media/helmfile.yaml lint
```

### Checklist de validation
- [ ] Releases Helm passent `helmfile lint`
- [ ] ClusterIssuer `letsencrypt-prod` OK
- [ ] DNS records créés par external-dns
- [ ] Ingress TLS valides pour chaque app
- [ ] NetworkPolicies appliquées (deny par défaut)
- [ ] qBittorrent ne sort pas sans VPN actif
- [ ] Probes OK, ressources stables, aucune OOM
- [ ] Metrics visibles dans Prometheus/Grafana
- [ ] Backups Velero programmés et test de restore documenté

