#!/usr/bin/env bash
#
# Rend une Application ArgoCD sans déchiffrer les secrets.
#
# Les generateurs KSOPS sont retirés d'une copie temporaire du repo : on valide
# la structure, les refs Kustomize, les charts Helm et les manifests hors
# secrets. Les fichiers secrets eux-mêmes sont vérifiés séparément (SOPS).
set -euo pipefail

app="${1:?usage: render-app.sh <app-name>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cp -R "$root/argocd" "$tmp/argocd"

python3 - "$tmp/argocd" <<'PY'
import pathlib
import sys

import yaml

root = pathlib.Path(sys.argv[1])
for path in root.rglob("kustomization.yaml"):
    data = yaml.safe_load(path.read_text())
    if isinstance(data, dict) and "generators" in data:
        data.pop("generators", None)
        path.write_text(yaml.safe_dump(data, sort_keys=False))
PY

kustomize build --enable-helm "$tmp/argocd/apps/$app"
