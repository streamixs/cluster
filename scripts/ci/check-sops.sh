#!/usr/bin/env bash
#
# Vérifie que les fichiers de secrets suivis par Git sont bien chiffrés SOPS.
# On ne déchiffre pas : on vérifie la présence des marqueurs SOPS et ENC[].
set -euo pipefail

fail=0

while IFS= read -r f; do
  case "$f" in
    .sops.yaml|*.example.yaml) continue ;;
  esac

  if ! grep -q '^sops:' "$f"; then
    echo "ERREUR: métadonnées SOPS absentes: $f"
    fail=1
  fi

  if ! grep -q 'ENC\[AES256_GCM' "$f"; then
    echo "ERREUR: valeur non chiffrée: $f"
    fail=1
  fi
done < <(
  git ls-files \
    '*/secrets/*.yaml' \
    '*.sops.yaml' \
    'argocd/base/cert-manager/issuers/secret-cf-token.yaml'
)

exit "$fail"
