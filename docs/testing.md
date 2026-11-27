# Testing avant merge

Objectif : attraper un maximum d'erreurs **avant** le merge sur `main`, sans
maintenir un second cluster permanent.

## Ce que la CI vérifie aujourd'hui

- `yamllint` sur le repo.
- `kustomize build --enable-helm` par app (avec un angle mort KSOPS).
- `kubeconform` sur les manifests rendus, avec `-ignore-missing-schemas`.
- `gitleaks` sur l'historique.

## Angles morts connus

- Les apps KSOPS (`media`, `cert-manager`, `hermes`, `securo`,
  `traefik-forward-auth`) sont **sautées** par `validate-kustomize`.
  `media` en entier n'est donc pas validée.
- `KUBERNETES_VERSION` de la CI est encore `1.32.0` alors que la prod est en
  `1.35.3`.
- Les CRDs ne sont pas validées (`-ignore-missing-schemas`).
- Terraform, Talos, `actionlint` et `shellcheck` ne sont pas validés.
- Aucun test d'admission réel (kind/k3d) n'est exécuté.

Ces points sont suivis dans `TODO.md`.

## Vérifications locales

### YAML

```bash
yamllint -c .yamllint.yaml .
```

### Rendu Kustomize

Pour une app sans KSOPS :

```bash
kustomize build --enable-helm argocd/apps/<app>
```

Pour une app avec KSOPS, installer `ksops` et la clé age :

```bash
export SOPS_AGE_KEY_FILE="$PWD/.config/age.agekey"
kustomize build --enable-helm argocd/apps/media
```

Sans clé age, on peut au moins vérifier la structure en retirant temporairement
les blocs `generators:` dans une copie de travail. Ne jamais commiter cette
copie modifiée.

### Terraform

```bash
cd terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

### Diff avant sync

Quand le cluster est accessible :

```bash
kubectl --kubeconfig ~/.talos/kubeconfig-prod diff -k argocd
```

Pour une app ArgoCD :

```bash
argocd app diff <app>
```

## Lab jetable

Un lab `kind`/`k3d` peut être utilisé pour tester une app, une IngressRoute ou
une values Helm. Règles :

- pas de données de prod,
- pas de domaine de prod,
- pas de secrets de prod,
- cluster créé puis détruit (`make lab-up` / `make lab-down` quand ce sera
  outillé).

Le lab ne remplace pas un test Talos/Cilium/Longhorn : ces composants doivent
être validés en lecture des release notes, avec backup et fenêtre de
maintenance.

## Checklist PR

- [ ] `yamllint` passe.
- [ ] Les apps modifiées rendent avec `kustomize build`.
- [ ] `terraform fmt/validate` passent si `terraform/` est modifié.
- [ ] Le diff ArgoCD a été relu pour les apps d'infrastructure.
- [ ] Un backup etcd/CNPG/Longhorn a été pris si le changement est risqué.
- [ ] Le plan de rollback est écrit dans la PR.
- [ ] Les secrets sont chiffrés SOPS, aucun secret en clair.
- [ ] Les images sont épinglées.
- [ ] Les ressources ont probes/resources/securityContext si applicable.

## Ce que la CI ne peut pas remplacer

- Un upgrade Talos/Cilium/Longhorn réel.
- Le comportement du GPU Intel et de Plex.
- Les accès NFS TrueNAS.
- Les données réelles d'Immich/Securo.
- La restauration d'un backup.

Pour ces cas : fenêtre de maintenance, backup, sync manuelle, surveillance, et
rollback Git (`git revert` + sync).
