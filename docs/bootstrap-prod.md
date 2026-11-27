# Bootstrap prod

Procédure manuelle pour reconstruire le cluster `prod` (Talos + Cilium + ArgoCD).

> Il n'y a plus d'environnement `dev` permanent. Un lab jetable peut être créé
> à la demande avec `kind`/`k3d`, mais il n'est jamais utilisé pour le bootstrap
> prod et ne monte jamais les données de prod.

## Prérequis

- `talosctl`, `talhelper`, `helm`, `kubectl`, `terraform`, `sops`, `age`, `yq`
- la clé age dans `.config/age.agekey`
- un accès réseau aux nœuds `192.168.1.30`, `.40`, `.41`, `.42`
- le kubeconfig cible : `~/.talos/kubeconfig-prod`

Vérifier les versions dans `talos/prod/talconfig.yaml` avant de commencer.

## 1. Générer et chiffrer les secrets Talos

```bash
make talos-gen-secret
```

Le secret est généré dans un fichier temporaire, chiffré avec SOPS, puis
déplacé vers `talos/prod/talsecret.sops.yaml`. Si le chiffrement échoue, le
fichier existant n'est pas remplacé.

Vérifier que le fichier est bien chiffré :

```bash
sops -d talos/prod/talsecret.sops.yaml >/dev/null && echo OK
```

## 2. Générer les machine configs

```bash
make talos-gen
```

Les fichiers sont écrits dans `talos/prod/clusterconfig/` (gitignored).
Ils contiennent des secrets et ne doivent jamais être commités.

## 3. Appliquer les configs Talos

Pour chaque nœud, en commençant par le control plane :

```bash
talosctl apply-config --insecure \
  --nodes 192.168.1.30 \
  --file talos/prod/clusterconfig/kube-master-01.yaml

talosctl apply-config --insecure \
  --nodes 192.168.1.40 \
  --file talos/prod/clusterconfig/kube-worker-01.yaml

# idem pour .41 et .42
```

Le flag `--insecure` sert uniquement à la première application, avant que le
certificat Talos du nœud ne soit approuvé.

## 4. Bootstrap etcd / Kubernetes

```bash
talosctl bootstrap --nodes 192.168.1.30
talosctl kubeconfig ~/.talos/kubeconfig-prod --nodes 192.168.1.30
```

Attendre que le control plane soit prêt :

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod get nodes -o wide
```

## 5. Installer Cilium

Cilium doit être installé **avant** ArgoCD : l'ApplicationSet et les CRDs
Cilium en dépendent.

```bash
make cilium
```

Le Makefile lit la version Cilium depuis `argocd/apps/cilium/kustomization.yaml`
et attend que tous les nœuds soient `Ready`.

## 6. Installer ArgoCD

```bash
make argocd
```

Terraform installe ArgoCD et crée le secret `sops-age` à partir de
`.config/age.agekey`.

Le state Terraform est local et contient des secrets en clair. Voir
`terraform/STATE.md` : le sauvegarder avant toute opération et ne jamais le
commiter.

Récupérer le mot de passe admin initial :

```bash
cd terraform
terraform output -raw argocd_admin_password
```

Après la première connexion :

1. changer le mot de passe admin (ou passer ArgoCD en OIDC),
2. supprimer `argocd-initial-admin-secret`,
3. ne pas laisser le mot de passe dans un fichier ou un historique de shell.

## 7. Créer le projet et l'ApplicationSet

```bash
make gitops
```

Cette commande applique `argocd/kustomization.yaml` : AppProject `platform` +
ApplicationSet. Sans elle, ArgoCD est installé mais **aucune Application n'est
créée**.

Vérifier :

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod \
  get applications -n argocd
```

## 8. Vérifications post-bootstrap

```bash
make status
kubectl --kubeconfig ~/.talos/kubeconfig-prod get certificates -A
kubectl --kubeconfig ~/.talos/kubeconfig-prod get volumes.longhorn.io -A
```

Checker :

- tous les nœuds `Ready`,
- Cilium en bonne santé,
- ArgoCD `Synced` / `Healthy`,
- certificats `Ready`,
- volumes Longhorn `healthy`,
- IngressRoutes joignables.

## 9. Après le bootstrap

- Mettre en place les backups (voir `docs/backup-restore.md`).
- Vérifier les enregistrements DNS et le certificat wildcard.
- Documenter toute déviation dans `docs/inventory.md`.
- Ne pas oublier que le control plane est unique : pas de HA, prévoir le
  restore etcd et les backups de données.
