# Testing avant merge

Objectif : attraper un maximum d'erreurs **avant** le merge sur `main`, sans
maintenir un second cluster permanent.

## Ce que la CI vérifie aujourd'hui

- `yamllint` sur le repo.
- `SOPS check` : les fichiers de secrets suivis sont bien chiffrés.
- Rendu de **toutes** les apps via `scripts/ci/render-app.sh` :
  `media`, `cert-manager`, `hermes`, `securo`, `traefik-forward-auth` inclus.
- `kubeconform` sur les manifests rendus, avec les schémas core + CRD Datree.
  Certains CRDs restent `skipped` faute de schéma, mais les types core et la
  majorité des CRDs sont validés.
- `terraform fmt -check`, `terraform init -backend=false`, `terraform validate`.
- `gitleaks` sur l'historique.
- Job agrégé `all-kustomize`, utilisable comme check requis.

## Angles morts connus

- `Pluto` n'est pas encore exécuté.
- `actionlint`, `shellcheck` et `renovate-config-validator` ne sont pas dans la CI.
- Talos n'est pas validé en CI.
- Aucun test d'admission réel (kind/k3d) n'est exécuté.
- La branch protection n'est pas encore active : les checks ne bloquent pas
  encore un merge.
- Les actions GitHub ne sont pas encore épinglées par SHA.

Ces points sont suivis dans `TODO.md`.

## Vérifications locales

### YAML

```bash
yamllint -c .yamllint.yaml .
```

### Rendu Kustomize

Le script CI rend n'importe quelle app sans déchiffrer les secrets (il retire
les générateurs KSOPS dans une copie temporaire) :

```bash
# nécessite PyYAML : python3 -m pip install --user pyyaml
./scripts/ci/render-app.sh <app> > /tmp/rendered.yaml
```

Pour une app sans KSOPS, le rendu direct fonctionne aussi :

```bash
kustomize build --enable-helm argocd/apps/<app>
```

Pour une app avec KSOPS et la vraie clé age :

```bash
export SOPS_AGE_KEY_FILE="$PWD/.config/age.agekey"
kustomize build --enable-helm argocd/apps/media
```

Ne jamais commiter une copie modifiée du repo pour contourner KSOPS.

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
