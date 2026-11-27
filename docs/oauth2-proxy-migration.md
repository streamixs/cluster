# Migration traefik-forward-auth → oauth2-proxy

## Pourquoi

`thomseddon/traefik-forward-auth:2` pointe sur une image Docker Hub de 2020,
et le projet n'a plus de release depuis 2024. On le remplace par
**oauth2-proxy**, maintenu, compatible OIDC/Pocket-ID et ForwardAuth Traefik.

La migration se fait en deux temps :

- **PR A1** : déployer oauth2-proxy en parallèle, tester sur une seule app.
- **PR A2** : basculer le middleware global, retirer l'ancien forward-auth.

## PR A1 — déploiement en parallèle

Cette PR ajoute :

- le Deployment/Service `oauth2-proxy` (2 replicas, PDB, probes) ;
- un middleware temporaire `forward-auth-oauth2` ;
- la route callback `oauth2-callback` ;
- la NetworkPolicy (Traefik → oauth2-proxy, oauth2-proxy → Pocket-ID) ;
- le secret SOPS `oauth2-proxy-secret` ;
- la bascule de **Tautulli uniquement** vers `forward-auth-oauth2`.

Les autres apps restent sur l'ancien `forward-auth`. Si le test échoue,
Tautulli est la seule app impactée.

## 1. Créer le client OIDC dans Pocket-ID

Créer un client OIDC :

- nom : `oauth2-proxy`
- redirect URI : `https://oauth.streamixs.com/oauth2/callback`
- scopes : `openid email profile`

Récupérer le `client-id` et le `client-secret`.

## 2. Renseigner le secret SOPS

```bash
make secret-edit FILE=argocd/base/oauth2-proxy/secrets/oauth2-proxy-secret.yaml
```

Remplacer :

- `client-id`
- `client-secret`

Le `cookie-secret` a déjà été généré aléatoirement et chiffré ; le conserver.
Il doit faire exactement **16, 24 ou 32 caractères** (pas 44). Pour le
régénérer : `openssl rand -hex 16` (32 caractères hex).

Vérifier les clés sans afficher les valeurs :

```bash
make secret-keys FILE=argocd/base/oauth2-proxy/secrets/oauth2-proxy-secret.yaml
```

## 3. Appliquer et tester

Après merge de la PR A1 et sync ArgoCD :

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod get pods -n auth
kubectl --kubeconfig ~/.talos/kubeconfig-prod get svc -n auth oauth2-proxy
```

Tester :

1. ouvrir `https://tautulli.streamixs.com` ;
2. vérifier la redirection vers Pocket-ID ;
3. vérifier le retour sur `https://oauth.streamixs.com/oauth2/callback` ;
4. vérifier l'accès à Tautulli après login ;
5. tester le logout ;
6. vérifier que les autres apps passent toujours par l'ancien forward-auth.

Logs :

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod logs -n auth deploy/oauth2-proxy --tail=100
```

## 4. Rollback A1

Si le test échoue :

```bash
# Remettre Tautulli sur l'ancien middleware
git revert <commit-tautulli>
```

Ou modifier `argocd/base/tautulli/ingressroute.yaml` pour remettre
`forward-auth`. Les autres apps ne sont pas affectées.

## 5. PR A2 — cutover global

Après validation :

- changer l'adresse du middleware `forward-auth` vers oauth2-proxy ;
- mettre à jour la route callback vers `/oauth2/` ;
- supprimer l'ancien callback `/_oauth` ;
- supprimer l'ancien Deployment/Service `traefik-forward-auth` ;
- supprimer l'ancien secret si plus utilisé ;
- remettre Tautulli sur `forward-auth` (qui pointera désormais vers
  oauth2-proxy) ;
- supprimer le middleware temporaire `forward-auth-oauth2` ;
- renommer éventuellement l'app `traefik-forward-auth` en `oauth2-proxy`.

Les utilisateurs devront se reconnecter une fois : le cookie change de
`_forward_auth` à `_oauth2_proxy`.

## Troubleshooting

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
- Le client OIDC `traefik-forward-auth` reste en place jusqu'à la fin de A2
  pour permettre le rollback.
