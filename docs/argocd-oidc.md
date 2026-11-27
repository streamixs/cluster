# ArgoCD : OIDC Pocket-ID et RBAC

ArgoCD peut déléguer l'authentification à Pocket-ID. Le compte `admin` local
reste disponible comme accès de secours.

## Fonctionnement

- Provider : Pocket-ID (`https://auth.streamixs.com`).
- Callback : `https://argocd.streamixs.com/auth/callback`.
- RBAC : `policy.default: role:readonly`, l'email admin est mappé sur
  `role:admin`.
- Le client secret OIDC est stocké dans le Secret Kubernetes `argocd-oidc`,
  créé par Terraform. Il n'est jamais dans Git ni dans les values Helm.
- ArgoCD lit le secret via `$argocd-oidc:client-secret`.

Le code Terraform est dans `terraform/resources/argocd/` :

- `argocd-oidc-values.yaml.tpl` : config OIDC + RBAC, rendue uniquement si OIDC
  est activé ;
- `main.tf` : Secret `argocd-oidc` et activation conditionnelle ;
- `variables.tf` : `argocd_oidc_client_id`, `argocd_oidc_client_secret`,
  `argocd_oidc_admin_email`.

## 1. Créer le client Pocket-ID

Dans Pocket-ID, créer un client OIDC :

- nom : `argocd`
- redirect URI : `https://argocd.streamixs.com/auth/callback`
- scopes : `openid email profile`

Récupérer le `client_id` et le `client_secret`.

## 2. Activer OIDC via Terraform

Depuis `terraform/`, avec le state local existant :

```bash
export TF_VAR_argocd_oidc_client_id='<client_id>'
export TF_VAR_argocd_oidc_client_secret='<client_secret>'
export TF_VAR_argocd_oidc_admin_email='<email Pocket-ID>'

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

Vérifier l'identité et le rôle :

```bash
argocd account get-user-info
```

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
- `permission denied` après login : vérifier `policy.csv` et le claim `email`
  (`scopes: "[email]"`).
- Le bouton Pocket-ID n'apparaît pas : vérifier `configs.cm.oidc.config` dans
  `argocd-cm` et les logs `argocd-server`.
