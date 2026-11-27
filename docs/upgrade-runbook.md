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

## Traefik 42.4.3 (fait le 2026-11-27)

État actuel : chart `42.4.3`, Traefik `v3.7.20`.

L'upgrade `40.3.0` → `42.4.3` a été effectué le 2026-11-27. Les CRDs 42.4.3
ont été appliquées avant le sync, puis l'app a été synchronisée manuellement.

Prochain palier : `43.0.0` (Traefik 3.8.0), après une période de cooling. Ne
pas sauter directement sans relire les release notes et appliquer les CRDs
correspondantes.

### Pré-requis

- Traefik doit être en **sync manuelle** ou dans une sync window. L'app est
  désormais en sync manuelle via l'exception `traefik` de l'ApplicationSet.
- Exporter les CRDs :

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod \
  get crd -o yaml > /tmp/all-crds-backup.yaml
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

1. Appliquer les CRDs avant le chart (pour le prochain upgrade, remplacer
   `42.4.3` par `43.0.0`) :

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
- image `traefik:v3.7.20` (ou `v3.8.0` pour le palier 43) ;
- PDB présent ;
- IP LoadBalancer `192.168.1.210` conservée ;
- toutes les IngressRoutes répondent ;
- oauth2-proxy et les apps protégées fonctionnent.

### Rollback

- `git revert` de la version du chart et sync.
- Les CRDs Traefik sont généralement rétrocompatibles, mais conserver
  `/tmp/all-crds-backup.yaml`.
- Si le rollback de chart ne suffit pas, restaurer les CRDs puis resynchroniser.

## ArgoCD (Terraform)

ArgoCD est installé par Terraform (`terraform/resources/argocd`), pas par
ArgoCD lui-même. L'upgrade se fait donc par `terraform apply`, pas par un sync
ArgoCD.

### Préflight

- Lire les notes d'upgrade ArgoCD de chaque minor traversée.
- Vérifier la PR Renovate (chart `argo-cd`) et l'`appVersion`.
- Sauvegarder `terraform.tfstate` et son `.backup`.
- Vérifier que `.config/argocd-oidc-secret` existe.

### Plan

Depuis `terraform/` :

```bash
export TF_VAR_kubeconfig=~/.talos/kubeconfig-prod
export TF_VAR_argocd_oidc_client_id='<client_id>'
export TF_VAR_argocd_oidc_client_secret="$(cat ../.config/argocd-oidc-secret)"
export TF_VAR_argocd_oidc_admin_group='admin'

terraform plan -out=tfplan-argocd
```

Les variables OIDC sont **obligatoires** : sans elles, le plan supprime la
config OIDC. Le plan attendu est `0 to add, 1 to change, 0 to destroy` (seul le
release Helm). Si autre chose bouge, arrêter.

### Apply

```bash
terraform apply tfplan-argocd
```

### Vérifier

```bash
helm -n argocd list
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n argocd get pods
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n argocd \
  get cm argocd-cm -o jsonpath='{.data.oidc\.config}'
curl -s https://argocd.streamixs.com/api/v1/settings | jq .oidcConfig
```

- Redirection `argocd.streamixs.com/auth/login` vers Pocket-ID.
- Sync d'une app KSOPS (`monitoring`) pour valider le repo-server.
- Applications `Synced` / `Healthy`.

### Rollback

- Revenir à la version précédente du chart dans Terraform, puis plan/apply avec
  les variables OIDC.
- Les CRDs ArgoCD sont normalement rétrocompatibles ; conserver une sauvegarde
  des CRDs avant un saut majeur.
- Le state est sauvegardé avant l'apply.

## Traefik / cert-manager

- Lire les breaking changes.
- Sync manuelle.
- Vérifier les certificats et les IngressRoutes.

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
