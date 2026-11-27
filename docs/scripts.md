# Scripts d'exploitation

## `scripts/rotate-argocd-password.sh`

Génère un nouveau mot de passe admin ArgoCD, met à jour `argocd-secret` et
redémarre `argocd-server`.

Prérequis : `kubectl`, `htpasswd` (`apache2-utils`), `openssl`.

```bash
KUBECONFIG=~/.talos/kubeconfig-prod ./scripts/rotate-argocd-password.sh
```

Le script affiche le nouveau mot de passe une seule fois. Le stocker dans un
gestionnaire de mots de passe, puis supprimer `argocd-initial-admin-secret`.

## `scripts/rotate-sops-key.sh`

Génère une nouvelle clé age, met à jour `.sops.yaml`, re-chiffre les fichiers
SOPS, remplace `.config/age.agekey` et met à jour le secret `sops-age` dans
ArgoCD.

Prérequis : `age`, `sops`, `kubectl`.

```bash
KUBECONFIG=~/.talos/kubeconfig-prod ./scripts/rotate-sops-key.sh
```

Points d'attention :

- faire un backup de l'ancienne clé et du state Terraform avant,
- le script modifie `.sops.yaml` avant de re-chiffrer : ne pas l'interrompre,
- après rotation, vérifier que tous les fichiers sont déchiffrables,
- purger l'ancienne clé du state Terraform et des backups,
- commiter `.sops.yaml` + les fichiers re-chiffrés.

## `make secret-edit`

Édite un secret SOPS en place.

```bash
make secret-edit FILE=argocd/base/securo/secrets/securo-secret.yaml
make secret-keys FILE=argocd/base/securo/secrets/securo-secret.yaml
```

## `scripts/hermes-migrate-pod.yaml`

Pod de migration one-shot des données Hermes du Mac vers le PVC. La migration
est terminée : ce manifeste est conservé uniquement comme référence historique
et peut être supprimé.
