# Upgrade runbook

Ce document décrit la procédure générale. Adapter la version et la fenêtre au
changement réel.

## Règles

- Pas de pré-prod permanent : le test se fait par lecture des release notes,
  backup, fenêtre de maintenance et rollback Git.
- Pour un changement d'infrastructure (Talos, Cilium, Longhorn, CNPG,
  cert-manager, Traefik), sync manuelle ou sync window.
- Un upgrade se fait **un nœud à la fois**.
- Ne jamais lancer un upgrade sans snapshot etcd récent.

## Préflight

```bash
make status
make etcd-backup
kubectl --kubeconfig ~/.talos/kubeconfig-prod get nodes
kubectl --kubeconfig ~/.talos/kubeconfig-prod get applications -n argocd
kubectl --kubeconfig ~/.talos/kubeconfig-prod get volumes.longhorn.io -A
kubectl --kubeconfig ~/.talos/kubeconfig-prod get certificates -A
```

Vérifier :

- tous les nœuds `Ready`,
- aucun volume Longhorn `degraded`,
- aucun certificat expiré/proche expiration,
- backups CNPG/Longhorn récents (quand ils existeront),
- espace disque suffisant,
- release notes lues, breaking changes identifiés.

## Kubernetes

```bash
# dry-run
make k8s-upgrade-check K8S_VERSION=v1.35.x

# upgrade
make k8s-upgrade K8S_VERSION=v1.35.x
```

Le Makefile cible le premier control plane. Surveiller :

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod get nodes -w
kubectl --kubeconfig ~/.talos/kubeconfig-prod get pods -A
```

## Talos

1. Mettre à jour `talosVersion` dans `talos/prod/talconfig.yaml`.
2. Régénérer les configs :

```bash
make talos-gen
```

3. Dry-run sur le premier CP :

```bash
make talos-upgrade-check TALOS_VERSION=v1.12.x
```

4. Upgrade node par node :

```bash
make talos-upgrade TALOS_VERSION=v1.12.x
```

Le Makefile boucle sur les nœuds de `talconfig.yaml`. Vérifier après chaque
nœud que le cluster reste sain.

## Cilium

Cilium n'autorise que les upgrades de minor consécutifs. Ne jamais sauter une
minor.

1. Lire les release notes Cilium.
2. Vérifier `argocd/apps/cilium/kustomization.yaml`.
3. Lancer `make cilium` (Helm) ou laisser ArgoCD synchroniser si le palier est
   prévu.
4. Surveiller les DaemonSets Cilium, Hubble, les nœuds et les IngressRoutes.

## Longhorn

1. Vérifier `preUpgradeChecker` (actuellement désactivé).
2. Vérifier les volumes `healthy` et les réplicas.
3. Lire les release notes Longhorn.
4. Mettre à jour le chart dans `argocd/apps/longhorn/kustomization.yaml`.
5. Sync manuelle, surveiller les volumes et les nœuds.

## CNPG

1. Backup des clusters (`immich-db`, `securo-db`).
2. Lire les release notes de l'opérateur.
3. Mettre à jour `argocd/apps/cloudnative-pg/kustomization.yaml`.
4. Sync manuelle de l'opérateur.
5. Vérifier les clusters CNPG et les backups.

## Traefik / cert-manager / ArgoCD

- Lire les breaking changes.
- Sync manuelle.
- Vérifier les certificats et les IngressRoutes.
- Pour ArgoCD, attention au self-management et au repo-server.

## Rollback

- GitOps : `git revert` du commit fautif, puis sync ArgoCD.
- Talos/Kubernetes : utiliser les snapshots etcd et la procédure Talos.
- CNPG/Longhorn : restore depuis backup.
- Documenter l'incident et la décision.

## Post-upgrade

- `make status`
- Applications ArgoCD `Synced` / `Healthy`
- Certificats `Ready`
- Volumes Longhorn `healthy`
- Aucun pod en `CrashLoopBackOff`
- Backup suivant planifié
