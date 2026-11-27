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

## Alertes de base

Les règles par défaut de kube-prometheus-stack sont activées. Les alertes
spécifiques à ajouter ensuite :

- expiration des certificats,
- volumes Longhorn dégradés,
- backups CNPG en échec (quand les backups seront possibles),
- disque faible,
- pods en CrashLoopBackOff.
