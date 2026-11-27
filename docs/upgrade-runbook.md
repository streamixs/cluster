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

## Traefik 42.4.3

Cible actuelle : chart `40.3.0` (Traefik `v3.7.4`) → chart `42.4.3`
(Traefik `v3.7.20`). Ne pas sauter directement en `43.0.0` (Traefik 3.8.0)
sans période de cooling.

### Pré-requis

- Traefik doit être en **sync manuelle** ou dans une sync window. L'app est
  actuellement en auto-sync ; la merger sans pause applique l'upgrade
  immédiatement.
- Exporter les CRDs :

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod \
  get crd -l app.kubernetes.io/name=traefik -o yaml \
  > /tmp/traefik-crds-backup.yaml
```

### Migration des values

Le chart 42 remplace `logs` par `log` + `accessLog` :

```yaml
log:
  level: INFO
accessLog:
  enabled: true
```

### Upgrade

1. Appliquer les CRDs avant le chart :

```bash
helm show crds traefik/traefik --version 42.4.3 \
  | kubectl --kubeconfig ~/.talos/kubeconfig-prod \
      apply --server-side --force-conflicts -f -
```

2. Vérifier le rendu :

```bash
kustomize build --enable-helm argocd/apps/traefik >/tmp/traefik.yaml
kubeconform -strict -summary -kubernetes-version 1.35.3 \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  -ignore-missing-schemas /tmp/traefik.yaml
```

3. Mettre Traefik en sync manuelle, puis sync ArgoCD.
4. Vérifier :

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n traefik get deploy,pods,pdb
kubectl --kubeconfig ~/.talos/kubeconfig-prod get ingressroute -A
kubectl --kubeconfig ~/.talos/kubeconfig-prod get certificates -A
```

- Deployment `traefik` 2/2 ;
- image `traefik:v3.7.20` ;
- PDB présent ;
- IP LoadBalancer `192.168.1.210` conservée ;
- toutes les IngressRoutes répondent ;
- oauth2-proxy et les apps protégées fonctionnent.

### Rollback

- `git revert` de la version du chart et sync.
- Les CRDs Traefik sont généralement rétrocompatibles, mais conserver
  `/tmp/traefik-crds-backup.yaml`.
- Si le rollback de chart ne suffit pas, restaurer les CRDs puis resynchroniser.

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
