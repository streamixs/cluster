# Migration traefik-forward-auth → oauth2-proxy

## État actuel

La migration est terminée : **oauth2-proxy** remplace complètement
`traefik-forward-auth` pour le middleware Traefik `forward-auth`.

- Middleware : `auth/forward-auth`
- Adresse : `http://oauth2-proxy.auth.svc.cluster.local:4180/`
- Callback : `https://oauth.streamixs.com/oauth2/callback`
- Provider : Pocket-ID (OIDC)
- Cookie : `_oauth2_proxy`, domaine `.streamixs.com`
- 2 replicas, PDB, probes, NetworkPolicy

Toutes les IngressRoutes protégées continuent de référencer `forward-auth` :
elles n'ont pas eu à changer.

L'ancien `traefik-forward-auth` (Deployment, Service, callback `/_oauth`,
secret, générateur KSOPS) a été supprimé.

> Le dossier d'application ArgoCD s'appelle encore
> `argocd/apps/traefik-forward-auth` pour éviter un remplacement d'Application.
> Un renommage vers `oauth2-proxy` pourra être fait dans une PR de suivi.

## Pourquoi ce remplacement

`thomseddon/traefik-forward-auth:2` pointait sur une image Docker Hub de 2020,
et le projet n'a plus de release depuis 2024. `oauth2-proxy` est maintenu,
compatible OIDC/Pocket-ID et ForwardAuth Traefik.

## Reconstruction / configuration

### Client OIDC Pocket-ID

Créer un client OIDC :

- nom : `oauth2-proxy`
- redirect URI : `https://oauth.streamixs.com/oauth2/callback`
- scopes : `openid email profile`

### Secret SOPS

```bash
make secret-edit FILE=argocd/base/oauth2-proxy/secrets/oauth2-proxy-secret.yaml
```

Clés :

- `client-id`
- `client-secret`
- `cookie-secret` : exactement **16, 24 ou 32 caractères**
  (`openssl rand -hex 16` produit 32 caractères).

Vérifier sans afficher les valeurs :

```bash
make secret-keys FILE=argocd/base/oauth2-proxy/secrets/oauth2-proxy-secret.yaml
```

### Middleware

```yaml
forwardAuth:
  address: http://oauth2-proxy.auth.svc.cluster.local:4180/
  trustForwardHeader: true
  authResponseHeaders:
    - X-Auth-Request-User
    - X-Auth-Request-Email
```

`OAUTH2_PROXY_UPSTREAMS=static://202` fait renvoyer `202` quand la session est
valide.

## Vérifications

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n auth get deploy,svc,pods
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n auth logs deploy/oauth2-proxy --tail=100
```

Au démarrage, les logs doivent contenir :

```text
Cookie settings: ... domains:.streamixs.com ...
```

Tester :

1. ouvrir une app protégée ;
2. redirection vers Pocket-ID ;
3. retour sur `https://oauth.streamixs.com/oauth2/callback` ;
4. accès à l'app ;
5. logout ;
6. vérifier le cookie `_oauth2_proxy` sur `.streamixs.com`.

## Rollback

Un `git revert` de la PR de cutover recrée l'ancien
Deployment/Service/Middleware/callback `traefik-forward-auth`, à condition que
le revert inclue la restauration du secret SOPS supprimé.

Les utilisateurs devront se reconnecter une fois : le cookie change de
`_forward_auth` à `_oauth2_proxy`.

## Troubleshooting

### `Unauthorized` au lieu d'une redirection vers Pocket-ID

Traefik `forwardAuth` doit pointer vers la **racine** d'oauth2-proxy, pas vers
`/oauth2/auth` :

```yaml
forwardAuth:
  address: http://oauth2-proxy.auth.svc.cluster.local:4180/
```

Avec `/oauth2/auth`, oauth2-proxy renvoie `401` sans cookie et Traefik le
transmet tel quel. Avec `/`, il renvoie `302` vers Pocket-ID.

Une alternative est d'utiliser un middleware `errors` avec
`query: "/oauth2/start?rd={url}"` et `statusRewrites: "401": 302`, mais elle
oblige à ajouter ce middleware sur chaque IngressRoute.

### `403 Forbidden` après le callback Pocket-ID

Vérifier les logs au démarrage :

```text
Cookie settings: ... domains: path:/
```

Si `domains:` est vide, le cookie n'est valable que pour
`oauth.streamixs.com` et n'est pas envoyé aux autres sous-domaines.
La variable d'environnement doit être **`OAUTH2_PROXY_COOKIE_DOMAINS`**
(pluriel), pas `OAUTH2_PROXY_COOKIE_DOMAIN` :

```yaml
- name: OAUTH2_PROXY_COOKIE_DOMAINS
  value: .streamixs.com
```

### `cookie_secret must be 16, 24, or 32 bytes`

Le secret a été généré en base64 (44 caractères). oauth2-proxy attend une
chaîne de 16, 24 ou 32 caractères. Régénérer avec :

```bash
cookie=$(openssl rand -hex 16)
SOPS_AGE_KEY_FILE=.config/age.agekey \
  sops set argocd/base/oauth2-proxy/secrets/oauth2-proxy-secret.yaml \
  '["stringData"]["cookie-secret"]' "\"$cookie\""
```

Puis redémarrer le deployment après sync :

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod rollout restart deploy/oauth2-proxy -n auth
```

## Notes de sécurité

- `oauth2-proxy` tourne en non-root (UID 65532), rootfs read-only, capabilities
  drop ALL.
- L'ingress est limité à Traefik ; l'egress à `auth.streamixs.com:443`.
- Le secret est chiffré SOPS ; ne jamais commiter les valeurs réelles.
- `--reverse-proxy=true` est nécessaire derrière Traefik. Un
  `--trusted-proxy-ip` pourra être ajouté quand l'adressage des pods Traefik
  sera stable.
