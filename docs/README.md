Media automation stack on Kubernetes (streamixs.com)

Prerequisites
- Kubernetes >=1.27, admin access
- Ingress NGINX, cert-manager, external-dns, Prometheus Operator, Loki/Promtail (installed by infra helmfile)
- Public domain: streamixs.com
- ACME email: louis.sasse@protonmail.com
- DNS provider: Cloudflare (API token sealed)
- StorageClass: <STORAGE_CLASS>
- PUID/PGID matching NAS permissions
- S3-compatible storage for Velero

Replace placeholders
- <STORAGE_CLASS>
- <PUID>, <PGID>
- <S3_BUCKET_NAME>, <S3_REGION>, <S3_ENDPOINT_URL>, <S3_ACCESS_KEY_ID>, <S3_SECRET_ACCESS_KEY>
- <VPN_PROVIDER> and Gluetun env via Secret `gluetun-vpn-secret`

Bootstrap
1) Install Sealed Secrets controller and create SealedSecrets per secrets/*.sealed.yaml
2) make bootstrap
3) make apply-infra
4) make apply-media

GitOps with ArgoCD
- Apply `argocd/appproject.yaml` and `argocd/applications.yaml` after updating <GIT_REPO_URL>

Network
- Default deny policies in `networkpolicies/` with allow from ingress-nginx and DNS egress.
- qBittorrent locked to Gluetun via policy `qbittorrent-egress-only-to-gluetun`.

Storage
- PVCs: /config, /downloads, /media. Ensure RWX for media if shared.

Observability
- Kube-Prometheus-Stack deployed; ServiceMonitors enabled per app.
- Blackbox exporter probes public HTTPS endpoints.
- Loki+Promtail for logs.

Backups
- Velero installed with Restic node agent. Daily schedule for namespace media.

Operations
- Switch Jellyfin/Plex in `values/media/environment-default.yaml`.
- Update PUID/PGID and storage classes in values.

Security
- Non-root, read-only FS when possible, seccomp runtime/default, drop ALL caps except NET_ADMIN in Gluetun.

