# Network policies et Pod Security Standards

## CiliumNetworkPolicy

Les policies ArgoCD sont dans
`argocd/apps/argocd/networkpolicies.yaml`. Chaque policy sélectionne un
composant et active le deny-by-default en ingress et egress.

Pour ne pas casser les flux internes, tout le trafic entre pods du namespace
`argocd` est autorisé. Les flux externes sont ouverts explicitement :

- DNS vers `kube-dns` ;
- `kube-apiserver` ;
- `argocd-server` → `auth.streamixs.com:443` (OIDC Pocket-ID) ;
- `argocd-notifications-controller` → `api.telegram.org:443` ;
- `argocd-repo-server` → GitHub, releases GitHub, dépôts Helm et `ghcr.io`.

### Ajouter un dépôt Helm/OCI

Si une app utilise un nouveau dépôt, ajouter son domaine dans la règle
`toFQDNs` du `argocd-repo-server`, puis l'URL dans les `sourceRepos` de
`argocd/projects/platform.yaml`.

### Limites

`kubectl port-forward` passe par le kubelet et ne traverse pas le datapath
Cilium. Les probes kubelet continuent de fonctionner.

## Pod Security Standards

| Namespace | Enforce | Remarque |
|---|---|---|
| `argocd` | `baseline` | labels gérés par Terraform |
| `auth` | `restricted` | oauth2-proxy |
| `media` | `baseline` | |
| `immich` | `baseline` | |
| `external-services` | `baseline` | aucun pod |
| `monitoring` | `privileged` | node-exporter a besoin des accès host |
| `longhorn-system` | `privileged` | |
| `hermes` | `baseline` / `restricted` | existant |

`argocd` reste en `baseline` pour l'instant : le chart ArgoCD et l'init
container KSOPS ne sont pas encore tous compatibles `restricted`. Une fois
ArgoCD v10 et KSOPS validés, repasser le namespace en `restricted` si possible.

## Vérifier

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod get ns --show-labels \
  | rg 'pod-security'
kubectl --kubeconfig ~/.talos/kubeconfig-prod get ciliumnetworkpolicy -A
```

Tester le PSS sans créer de pod :

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod -n auth apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pss-test
spec:
  containers:
    - name: pss-test
      image: busybox
      securityContext:
        privileged: true
EOF
```

La création doit être refusée par `restricted` (et par `baseline` dans
`media`/`immich`/`argocd`).
