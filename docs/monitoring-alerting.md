# Monitoring et alerting

## Alertmanager → Telegram

Alertmanager envoie les alertes via un bot Telegram. Le token du bot est stocké
en SOPS ; le `chat_id` reste dans les values (ce n'est pas un secret).

### Créer le bot Telegram

1. Créer un bot dédié via **@BotFather** : `/newbot`.
2. Récupérer le token.
3. Envoyer un message au bot (ou l'ajouter à un groupe).
4. Récupérer le `chat_id` :

```bash
curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" \
  | jq '.result[].message.chat | {id, title, username}'
```

Pour un chat privé, on peut aussi utiliser `@userinfobot`.
Pour un groupe, le `chat_id` est négatif.

Éviter de réutiliser le bot Hermes : garder un bot dédié à l'alerting évite de
mélanger les messages de l'agent et les alertes.

### Renseigner le token

```bash
make secret-edit FILE=argocd/base/monitoring/secrets/alertmanager-telegram-secret.yaml
```

Remplacer `bot-token`.

Vérifier :

```bash
make secret-keys FILE=argocd/base/monitoring/secrets/alertmanager-telegram-secret.yaml
```

### Renseigner le chat_id

Dans `argocd/apps/monitoring/values-kube-prometheus-stack.yaml` :

```yaml
alertmanager:
  config:
    route:
      receiver: telegram
      routes: []
    receivers:
      - name: telegram
        telegram_configs:
          - bot_token_file: /etc/alertmanager/secrets/alertmanager-telegram/bot-token
            chat_id: 123456789  # remplacer par le vrai chat_id
            parse_mode: HTML
            send_resolved: true
  alertmanagerSpec:
    secrets:
      - alertmanager-telegram
```

Le Secret est monté par l'opérateur dans
`/etc/alertmanager/secrets/alertmanager-telegram/`.

`externalUrl` est renseigné pour Prometheus
(`https://prometheus.streamixs.com`) et Alertmanager
(`https://alertmanager.streamixs.com`) : les liens « Source » des notifications
pointent donc vers les URLs publiques, derrière `forward-auth`, au lieu du
service interne `*.monitoring.svc`.

### Tester

L'alerte `Watchdog` est envoyée en permanence. Après sync, vérifier :

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n monitoring \
  get secret alertmanager-kps-kube-prometheus-stack-alertmanager \
  -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d
```

Puis vérifier la réception dans Telegram. Si rien n'arrive :

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n monitoring \
  logs statefulset/kps-kube-prometheus-stack-alertmanager --tail=100
```

## Grafana

Le mot de passe admin n'est plus `changeme`. Il est stocké dans le Secret SOPS
`grafana-admin`.

### Récupérer le mot de passe

```bash
SOPS_AGE_KEY_FILE=.config/age.agekey \
  sops -d argocd/base/monitoring/secrets/grafana-admin-secret.yaml \
  | yq -r '.stringData["admin-password"]'
```

L'utilisateur est `admin`.

### Modifier le mot de passe

```bash
make secret-edit FILE=argocd/base/monitoring/secrets/grafana-admin-secret.yaml
```

Le Secret n'est appliqué qu'à la création de l'utilisateur `admin`. Pour un
Grafana existant, le redémarrage ne change pas le mot de passe en base. Après
sync ArgoCD, réinitialiser explicitement avec le CLI (le mot de passe est lu
depuis l'environnement du pod, il n'apparaît pas dans la commande) :

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n monitoring \
  exec deploy/kps-grafana -c grafana -- \
  sh -c 'grafana cli --homepath /usr/share/grafana admin reset-admin-password "$GF_SECURITY_ADMIN_PASSWORD"'
```

Puis se connecter à Grafana avec `admin` et le mot de passe SOPS.

Le PVC Grafana est en `ReadWriteOnce` sur Longhorn. Le Deployment utilise donc
`deploymentStrategy: Recreate` avec `rollingUpdate: null` : un `RollingUpdate`
resterait bloqué en `Multi-Attach error` puisque l'ancien pod conserve le
volume tant que le nouveau n'est pas prêt. `rollingUpdate: null` est nécessaire
pour retirer le champ default côté API, sinon l'apply est refusé. Attendre
quelques secondes d'indisponibilité pendant un redémarrage est normal.

## Alertes

Les règles par défaut de kube-prometheus-stack restent actives, notamment :

- `KubePodCrashLooping` (warning, 15 min) pour les CrashLoopBackOff ;
- `NodeFilesystemAlmostOutOfSpace` (warning 5 %, critical 3 %) ;
- `NodeFilesystemSpaceFillingUp` (prédictif).

Les règles spécifiques sont dans `argocd/base/monitoring/alerts.yaml` :

| Alerte | Sévérité | Seuil |
|---|---|---|
| `CertManagerCertificateExpiringSoon` | warning | expire < 21 j |
| `CertManagerCertificateExpired` | critical | expiré |
| `CertManagerCertificateNotReady` | critical | condition False > 15 min |
| `LonghornVolumeDegraded` | warning | robustness 2 > 15 min |
| `LonghornVolumeFaulted` | critical | robustness 3 > 5 min |
| `LonghornNodeStorageLow` | warning | > 85 % utilisé > 30 min |
| `LonghornNodeStorageCritical` | critical | > 95 % utilisé > 15 min |
| `NodeFilesystemFreeSpaceLow` | warning | < 15 % libre > 30 min |
| `CNPGCollectorDown` | critical | collector down > 10 min |
| `CNPGReplicationLag` | warning | lag > 30 s > 10 min |
| `CNPGWaitingBackends` | warning | backends en attente > 15 min |

Pas de règle custom pour CrashLoopBackOff : `KubePodCrashLooping` couvre déjà
le cas, avec un `for` de 15 min.

### Certificats cert-manager

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod get certificates -A
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n <namespace> \
  describe certificate <name>
kubectl --kubeconfig ~/.talos/kubeconfig-prod get certificaterequests,orders,challenges -A
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n kube-system \
  logs deploy/cert-manager --tail=100
```

Vérifier l'issuer, le DNS01 Cloudflare et les événements du `Certificate`.
Un certificat expiré peut être forcé par la suppression du Secret TLS associé
(le Certificate le recrée).

### Longhorn

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n longhorn-system \
  get volumes.longhorn.io
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n longhorn-system \
  describe volume <volume>
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n longhorn-system get nodes.longhorn.io
```

Vérifier les réplicas, les nœuds disponibles et l'espace disque. Un volume
`degraded` peut être transitoire pendant un rebuild ; un volume `faulted`
nécessite une intervention. Ne pas supprimer un volume ou un PVC pour résoudre
une alerte sans backup.

### Disque node

```bash
talosctl -n 192.168.1.30 get mounts
talosctl -n 192.168.1.40 get mounts
talosctl -n 192.168.1.41 get mounts
talosctl -n 192.168.1.42 get mounts
```

Dans Prometheus/Grafana, vérifier l'espace libre par nœud et mountpoint :

```promql
(node_filesystem_avail_bytes{job="node-exporter",fstype!~"tmpfs|overlay|squashfs"}
 / node_filesystem_size_bytes{job="node-exporter",fstype!~"tmpfs|overlay|squashfs"}) * 100
```

Les alertes par défaut restent actives à 5 %/3 %. La règle custom sert
d'alerte précoce à 15 %. Vérifier les images inutilisées, les logs et les
volumes Longhorn avant de nettoyer.

### CNPG

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n immich get cluster immich-db
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n securo get cluster securo-db
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n immich \
  get pods -l cnpg.io/cluster=immich-db
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n securo \
  get pods -l cnpg.io/cluster=securo-db
```

Vérifier `cnpg_collector_up`, les logs du pod PostgreSQL et l'état du cluster.
Les backups ne sont pas encore configurés : ne pas compter sur
`cnpg_pg_stat_archiver_failed_count` pour le moment.

### CrashLoopBackOff

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod get pods -A \
  | rg 'CrashLoopBackOff|Error'
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n <namespace> \
  describe pod <pod>
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n <namespace> \
  logs <pod> --previous
```

### Silence

Pour une maintenance planifiée, créer un silence dans
`https://alertmanager.streamixs.com` plutôt que de désactiver la règle.
Documenter la raison et la durée dans la PR ou le runbook.
