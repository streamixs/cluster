# Inventaire

> Document opérationnel. Ne jamais y mettre de secret. Mettre à jour après
> chaque changement d'infra.

## Nœuds

| Rôle | Hostname | IP | Disque |
|---|---|---|---|
| Control plane | `kube-master-01` | `192.168.1.30` | `/dev/sda` |
| Worker | `kube-worker-01` | `192.168.1.40` | `/dev/nvme0n1` |
| Worker | `kube-worker-02` | `192.168.1.41` | `/dev/nvme0n1` |
| Worker | `kube-worker-03` | `192.168.1.42` | `/dev/nvme0n1` |

- Talos : `v1.12.6`
- Kubernetes : `v1.35.3`
- Endpoint API : `https://192.168.1.30:6443`
- Control plane unique : pas de HA. Voir `docs/backup-restore.md`.

## Réseau / LoadBalancer

| Usage | IP |
|---|---|
| Traefik | `192.168.1.210` |
| qBittorrent BitTorrent | `192.168.1.219` |
| qBittorrent seed BitTorrent | `192.168.1.220` |
| Pool Cilium LB | `192.168.1.210`–`192.168.1.220` |

## Stockage

| Usage | Type | Emplacement |
|---|---|---|
| Médias | NFS | `192.168.1.10:/mnt/data/media` (9 Ti, RWX) |
| Photos Immich | NFS | `192.168.1.10:/mnt/data/photos` (2 Ti, RWX) |
| Configs apps | Longhorn | PVC RWO, 2 réplicas |
| DB Immich / Securo | Longhorn via CNPG | PVC RWO |

## Services externes

| Service | IP | Port |
|---|---|---|
| TrueNAS | `192.168.1.10` | 80 |
| Pocket-ID | `192.168.1.4` | 1411 |
| Home Assistant | `192.168.1.21` | 8123 |
| Ollama (VM Proxmox) | `192.168.1.22` | 11434 |

## Domaines / Ingress

| Host | App | Auth |
|---|---|---|
| `argocd.streamixs.com` | ArgoCD | admin local (OIDC à venir) |
| `auth.streamixs.com` | Pocket-ID | native |
| `oauth.streamixs.com` | traefik-forward-auth callback | native |
| `grafana.streamixs.com` | Grafana | forward-auth |
| `prometheus.streamixs.com` | Prometheus | forward-auth |
| `alertmanager.streamixs.com` | Alertmanager | forward-auth |
| `photos.streamixs.com` | Immich | native |
| `securo.streamixs.com` | Securo | OIDC natif |
| `hermes.streamixs.com` | Hermes | OIDC natif |
| `plex.streamixs.com` | Plex | native Plex |
| `ha.streamixs.com` | Home Assistant | native |
| `truenas.streamixs.com` | TrueNAS | forward-auth |
| `sonarr.streamixs.com` | Sonarr | forward-auth |
| `radarr.streamixs.com` | Radarr | forward-auth |
| `lidarr.streamixs.com` | Lidarr | forward-auth |
| `prowlarr.streamixs.com` | Prowlarr | forward-auth |
| `qbittorrent.streamixs.com` | qBittorrent | forward-auth |
| `qbittorrent-seed.streamixs.com` | qBittorrent seed | forward-auth |
| `jellyseerr` / `seerr.streamixs.com` | Jellyseerr | forward-auth |
| `autobrr.streamixs.com` | Autobrr | forward-auth |
| `qui.streamixs.com` | Qui | forward-auth |
| `tautulli.streamixs.com` | Tautulli | forward-auth |
| `mixarr.streamixs.com` | Mixarr | forward-auth |

## Ports notables

- Traefik : 80/443, metrics 9100.
- qBittorrent BT : 30881 TCP/UDP.
- qBittorrent seed BT : 30882 TCP/UDP.
- Plex : 32400 (NodePort, bypass Traefik).
- ArgoCD server : 80/443 (HTTP interne, `server.insecure: true`).
- Traefik-forward-auth : 4181.

## Secrets

| Secret | Emplacement |
|---|---|
| Clé age | `.config/age.agekey` (gitignored, à sauvegarder offline) |
| Secrets SOPS | fichiers `*.sops.yaml` et `*/secrets/*.yaml` |
| State Terraform | `terraform/terraform.tfstate` (local, contient des secrets) |
| Secrets Talos | `talos/prod/talsecret.sops.yaml` (chiffré) |

## Vérifications

```bash
make status
kubectl --kubeconfig ~/.talos/kubeconfig-prod get applications -n argocd
kubectl --kubeconfig ~/.talos/kubeconfig-prod get certificates -A
kubectl --kubeconfig ~/.talos/kubeconfig-prod get volumes.longhorn.io -A
```
