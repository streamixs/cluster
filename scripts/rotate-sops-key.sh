#!/usr/bin/env bash
# Rotate the SOPS age key:
#   1. Generate a new age keypair
#   2. Re-encrypt all .sops.yaml files with the new key
#   3. Update .sops.yaml with the new public key
#   4. Update the sops-age Kubernetes secret in the cluster
#
# Requires: age, sops, kubectl
set -euo pipefail

NAMESPACE=${ARGOCD_NAMESPACE:-argocd}
KUBECONFIG=${KUBECONFIG:-~/.talos/kubeconfig-prod}
AGE_KEY_DIR="${HOME}/.config/sops/age"
NEW_KEY_FILE="${AGE_KEY_DIR}/keys.txt.new"
REPO_ROOT=$(git rev-parse --show-toplevel)

command -v age-keygen >/dev/null 2>&1 || { echo "age required (brew install age / apt install age)"; exit 1; }
command -v sops >/dev/null 2>&1 || { echo "sops required"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl required"; exit 1; }

mkdir -p "${AGE_KEY_DIR}"

echo "==> Generating new age keypair at ${NEW_KEY_FILE}..."
age-keygen -o "${NEW_KEY_FILE}"
NEW_PUBLIC_KEY=$(grep "^# public key:" "${NEW_KEY_FILE}" | awk '{print $NF}')
echo "    New public key: ${NEW_PUBLIC_KEY}"

SOPS_FILES=$(find "${REPO_ROOT}" -name "*.sops.yaml" -o -name "*.sops.yml" 2>/dev/null)
if [[ -z "${SOPS_FILES}" ]]; then
  echo "No SOPS-encrypted files found."
else
  echo "==> Re-encrypting SOPS files..."
  for f in ${SOPS_FILES}; do
    echo "    ${f}"
    SOPS_AGE_KEY_FILE="${REPO_ROOT}/.config/age.agekey" \
      sops rotate --add-age "${NEW_PUBLIC_KEY}" --in-place "${f}"
    SOPS_AGE_KEY_FILE="${NEW_KEY_FILE}" \
      sops rotate --remove-age "$(grep "^# public key:" "${REPO_ROOT}/.config/age.agekey" | awk '{print $NF}')" --in-place "${f}" 2>/dev/null || true
  done
fi

echo "==> Updating .sops.yaml with new public key..."
OLD_PUBLIC_KEY=$(grep "age:" "${REPO_ROOT}/.sops.yaml" | awk '{print $NF}' | tr -d "'" | head -1)
sed -i.bak "s|${OLD_PUBLIC_KEY}|${NEW_PUBLIC_KEY}|g" "${REPO_ROOT}/.sops.yaml"
rm -f "${REPO_ROOT}/.sops.yaml.bak"

echo "==> Updating sops-age Kubernetes secret..."
kubectl --kubeconfig="${KUBECONFIG}" -n "${NAMESPACE}" create secret generic sops-age \
  --from-file="keys.txt=${NEW_KEY_FILE}" \
  --dry-run=client -o yaml | \
  kubectl --kubeconfig="${KUBECONFIG}" apply -f -

echo "==> Restarting ArgoCD repo-server to reload the secret..."
kubectl --kubeconfig="${KUBECONFIG}" -n "${NAMESPACE}" rollout restart deployment argocd-repo-server
kubectl --kubeconfig="${KUBECONFIG}" -n "${NAMESPACE}" rollout status deployment argocd-repo-server --timeout=120s

echo ""
echo "==> Installing new key as active key..."
cp "${NEW_KEY_FILE}" "${REPO_ROOT}/.config/age.agekey"
rm -f "${NEW_KEY_FILE}"

echo ""
echo "==> DONE."
echo "    The new age private key is at: ${REPO_ROOT}/.config/age.agekey"
echo "    Commit and push the updated .sops.yaml and re-encrypted secrets."
echo ""
echo "    CRITICAL: The old key is now revoked. Delete it from all backups."
