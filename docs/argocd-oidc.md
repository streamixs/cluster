# ArgoCD : OIDC Pocket-ID et RBAC

ArgoCD peut déléguer l'authentification à Pocket-ID. Le compte `admin` local
reste disponible comme accès de secours.

> Statut : actif depuis le 2026-11-28 (ArgoCD `v3.4.4`), groupe admin `admin`.

## Fonctionnement

- Provider : Pocket-ID (`https://auth.streamixs.com`).
- Callback : `https://argocd.streamixs.com/auth/callback`.
- RBAC : `policy.default: role:readonly`, le groupe Pocket-ID admin est mappé
  sur `role:admin` via le claim `groups`.
- Le client secret OIDC est stocké dans le Secret Kubernetes `argocd-oidc`,
  créé par Terraform. Il n'est jamais dans Git ni dans les values Helm.
- ArgoCD lit le secret via `$argocd-oidc:client-secret`.

Le code Terraform est dans `terraform/resources/argocd/` :

- `argocd-oidc-values.yaml.tpl` : config OIDC + RBAC, rendue uniquement si OIDC
  est activé ;
- `main.tf` : Secret `argocd-oidc` et activation conditionnelle ;
- `variables.tf` : `argocd_oidc_client_id`, `argocd_oidc_client_secret`,
  `argocd_oidc_admin_group`.

## 1. Créer le client Pocket-ID

Dans Pocket-ID, créer un client OIDC :

- nom : `argocd`
- redirect URI : `https://argocd.streamixs.com/auth/callback`
- scopes : `openid email profile groups`

Récupérer le `client_id` et le `client_secret`.

Le groupe admin est le **nom exact** du groupe dans Pocket-ID (par exemple
`admin`). Pocket-ID renvoie les noms de groupes dans le claim `groups` quand le
scope `groups` est demandé.

## 2. Activer OIDC via Terraform

Depuis `terraform/`, avec le state local existant :

```bash
export TF_VAR_argocd_oidc_client_id='<client_id>'
export TF_VAR_argocd_oidc_client_secret='<client_secret>'
export TF_VAR_argocd_oidc_admin_group='<nom du groupe Pocket-ID>'

terraform plan
terraform apply
```

Ne pas mettre le client secret dans un fichier versionné. Le state Terraform
local contient le secret : voir `terraform/STATE.md`.

## 3. Vérifier

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n argocd \
  get cm argocd-cm -o jsonpath='{.data.oidc\.config}'

kubectl --kubeconfig ~/.talos/kubeconfig-prod -n argocd \
  get secret argocd-oidc
```

L'UI doit proposer le bouton **Log in via Pocket ID**. Le CLI :

```bash
argocd login argocd.streamixs.com --sso
```

Vérifier l'identité, les groupes et le rôle :

```bash
argocd account get-user-info
```

La sortie doit contenir le groupe admin (par exemple `Groups: [admin]`).

## 4. Accès de secours

Le compte `admin` local reste actif. Son mot de passe initial est dans
`argocd-initial-admin-secret` ; le changer après la première connexion.

Pour désactiver complètement l'admin local après validation :

```yaml
configs:
  cm:
    admin.enabled: "false"
```

À ne faire qu'après avoir confirmé que Pocket-ID et le RBAC fonctionnent, et
en gardant un moyen de réactivation (Terraform + accès au state).

## Désactiver OIDC

Retirer les trois variables (ou les laisser vides) puis :

```bash
terraform apply
```

Le Secret `argocd-oidc` est supprimé et la config OIDC retirée d'`argocd-cm`.
L'admin local reste disponible.

## Dépannage

- `failed to verify ID token` : vérifier l'issuer (`https://auth.streamixs.com`)
  et que le client Pocket-ID autorise bien le callback ArgoCD.
- `permission denied` après login : vérifier `policy.csv`, le scope `groups`
  côté client Pocket-ID, et `scopes: "[groups]"` dans `argocd-rbac-cm`.
- Le groupe n'apparaît pas dans `argocd account get-user-info` : vérifier
  `requestedScopes` (`groups`), `enableUserInfoGroups` et l'endpoint
  `/api/oidc/userinfo` de Pocket-ID.
- Le bouton Pocket-ID n'apparaît pas : vérifier `configs.cm.oidc.config` dans
  `argocd-cm` et les logs `argocd-server`.
