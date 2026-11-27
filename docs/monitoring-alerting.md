# Monitoring et alerting

## Alertmanager → Discord

Alertmanager envoie les alertes vers un webhook Discord stocké en SOPS.

### Créer le webhook Discord

Dans Discord : **Server Settings → Integrations → Webhooks → New Webhook**.
Copier l'URL du webhook.

### Renseigner le secret

```bash
make secret-edit FILE=argocd/base/monitoring/secrets/alertmanager-discord-secret.yaml
```

Remplacer `webhook-url` par l'URL Discord.

Vérifier :

```bash
make secret-keys FILE=argocd/base/monitoring/secrets/alertmanager-discord-secret.yaml
```

### Config Alertmanager

`argocd/apps/monitoring/values-kube-prometheus-stack.yaml` :

```yaml
alertmanager:
  config:
    route:
      receiver: discord
      routes: []
    receivers:
      - name: discord
        discord_configs:
          - webhook_url_file: /etc/alertmanager/secrets/alertmanager-discord/webhook-url
            send_resolved: true
  alertmanagerSpec:
    secrets:
      - alertmanager-discord
```

Le Secret est monté par l'opérateur dans
`/etc/alertmanager/secrets/alertmanager-discord/`.

### Tester

L'alerte `Watchdog` est envoyée en permanence. Après sync, vérifier :

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n monitoring \
  get secret alertmanager-kps-kube-prometheus-stack-alertmanager \
  -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d
```

Puis vérifier la réception dans Discord. Si rien n'arrive :

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

Puis sync ArgoCD et redémarrer Grafana si nécessaire :

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n monitoring \
  rollout restart deploy/kps-grafana
```

## Alertes de base

Les règles par défaut de kube-prometheus-stack sont activées. Les alertes
spécifiques à ajouter ensuite :

- expiration des certificats,
- volumes Longhorn dégradés,
- backups CNPG en échec (quand les backups seront possibles),
- disque faible,
- pods en CrashLoopBackOff.
