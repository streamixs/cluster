# TODO

> Review 2026-03-22

## P0 — Securite

- [ ] Auth sur les ingress media : deployer `oauth2-proxy` ou annotations `nginx.ingress.kubernetes.io/auth-*`
- [ ] NetworkPolicies : deny-all + allow-specific par namespace

## P1 — Important

- [ ] CI : ajouter `kubeconform` + validation Kustomize dans GitHub Actions
- [ ] Renovate Bot : auto-PR pour charts Helm et images Docker
- [ ] Security contexts sur les pods media (`readOnlyRootFilesystem`, `runAsNonRoot`, etc.)

## P2 — Amelioration

- [ ] ArgoCD targetRevision : passer de `develop` a `main`
- [ ] Grafana persistence : PVC pour dashboards
- [ ] NFS IP en variable (externaliser `54.36.178.170`)
- [ ] Evaluer Cilium IngressController pour remplacer ingress-nginx
