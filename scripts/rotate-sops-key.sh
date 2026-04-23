#!/usr/bin/env bash
# Rotate the SOPS age key:
#   1. Generate a new age keypair
#   2. Update .sops.yaml with the new public key
#   3. Re-key all SOPS-encrypted files via `sops updatekeys -y`
#      (decrypts with old key, re-encrypts exclusively with new key)
#   4. Replace the local age key file
#   5. Update the sops-age Kubernetes secret + restart argocd-repo-server
#
# Files are detected by content (ENC[AES256_GCM marker), not by extension,
# because the repo mixes .sops.yaml and plain .yaml encrypted files.
#
# Requires: age, sops, kubectl
set -euo pipefail

NAMESPACE=${ARGOCD_NAMESPACE:-argocd}
KUBECONFIG=${KUBECONFIG:-~/.talos/kubeconfig-prod}
AGE_KEY_DIR="${HOME}/.config/sops/age"
NEW_KEY_FILE="${AGE_KEY_DIR}/keys.txt.new"
REPO_ROOT=$(git rev-parse --show-toplevel)
CURRENT_KEY="${REPO_ROOT}/.config/age.agekey"

command -v age-keygen >/dev/null 2>&1 || { echo "age required (brew install age / apt install age)"; exit 1; }
command -v sops >/dev/null 2>&1 || { echo "sops required"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl required"; exit 1; }

[[ -f "${CURRENT_KEY}" ]] || { echo "Current age key not found at ${CURRENT_KEY}"; exit 1; }

mkdir -p "${AGE_KEY_DIR}"

echo "==> Generating new age keypair..."
age-keygen -o "${NEW_KEY_FILE}"
NEW_PUBLIC_KEY=$(grep "^# public key:" "${NEW_KEY_FILE}" | awk '{print $NF}')
echo "    New public key: ${NEW_PUBLIC_KEY}"

OLD_PUBLIC_KEY=$(grep "^# public key:" "${CURRENT_KEY}" | awk '{print $NF}')
echo "    Old public key: ${OLD_PUBLIC_KEY}"

# Detect SOPS-encrypted files by the ENC[AES256_GCM marker, regardless of extension.
SOPS_FILES=()
while IFS= read -r f; do
  SOPS_FILES+=("${f}")
done < <(grep -rl 'ENC\[AES256_GCM' "${REPO_ROOT}" \
  --include="*.yaml" --include="*.yml" --include="*.json" --include="*.env" 2>/dev/null)

if [[ ${#SOPS_FILES[@]} -eq 0 ]]; then
  echo "No SOPS-encrypted files found."
else
  echo "==> Found ${#SOPS_FILES[@]} SOPS-encrypted file(s):"
  printf '    %s\n' "${SOPS_FILES[@]}"
  echo ""

  # Update .sops.yaml BEFORE re-keying so that updatekeys uses the new recipient.
  echo "==> Updating .sops.yaml with new public key..."
  sed -i.bak "s|${OLD_PUBLIC_KEY}|${NEW_PUBLIC_KEY}|g" "${REPO_ROOT}/.sops.yaml"
  rm -f "${REPO_ROOT}/.sops.yaml.bak"

  # sops updatekeys reads recipients from .sops.yaml and re-encrypts.
  # Decryption uses the current (old) key; encryption uses the new key from .sops.yaml.
  # The -y flag auto-confirms without interactive prompt.
  echo "==> Re-keying files (sops updatekeys)..."
  for f in "${SOPS_FILES[@]}"; do
    echo "    ${f}"
    SOPS_AGE_KEY_FILE="${CURRENT_KEY}" sops updatekeys -y "${f}"
  done
fi

echo "==> Replacing local age key with new key..."
cp "${NEW_KEY_FILE}" "${CURRENT_KEY}"
rm -f "${NEW_KEY_FILE}"

echo "==> Updating sops-age Kubernetes secret..."
kubectl --kubeconfig="${KUBECONFIG}" -n "${NAMESPACE}" create secret generic sops-age \
  --from-file="keys.txt=${CURRENT_KEY}" \
  --dry-run=client -o yaml | \
  kubectl --kubeconfig="${KUBECONFIG}" apply -f -

echo "==> Restarting ArgoCD repo-server to reload the secret..."
kubectl --kubeconfig="${KUBECONFIG}" -n "${NAMESPACE}" rollout restart deployment argocd-repo-server
kubectl --kubeconfig="${KUBECONFIG}" -n "${NAMESPACE}" rollout status deployment argocd-repo-server --timeout=120s

echo ""
echo "==> DONE."
echo "    New age key active at: ${CURRENT_KEY}"
echo "    Commit and push: .sops.yaml + all re-encrypted secret files."
echo ""
echo "    CRITICAL: The old key is revoked. Purge it from all backups and the"
echo "    Terraform state (terraform.tfstate contains the old key in plaintext)."
