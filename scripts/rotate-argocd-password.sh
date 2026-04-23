#!/usr/bin/env bash
# Rotate the ArgoCD admin password.
# Requires: kubectl (context pointing to target cluster), htpasswd (apache2-utils), openssl
set -euo pipefail

NAMESPACE=${ARGOCD_NAMESPACE:-argocd}
KUBECONFIG=${KUBECONFIG:-~/.talos/kubeconfig-prod}

command -v htpasswd >/dev/null 2>&1 || { echo "htpasswd required (apt install apache2-utils)"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl required"; exit 1; }

echo "==> Generating new password..."
NEW_PASSWORD=$(openssl rand -base64 20 | tr -d '/+=' | head -c 24)

echo "==> Hashing with bcrypt (cost 10)..."
BCRYPT_HASH=$(htpasswd -bnBC 10 "" "${NEW_PASSWORD}" | tr -d ':\n')

echo "==> Patching argocd-secret in namespace ${NAMESPACE}..."
kubectl --kubeconfig="${KUBECONFIG}" -n "${NAMESPACE}" patch secret argocd-secret \
  --type=merge \
  -p "{
    \"stringData\": {
      \"admin.password\": \"${BCRYPT_HASH}\",
      \"admin.passwordMtime\": \"$(date -u +%FT%T%Z)\"
    }
  }"

echo "==> Restarting argocd-server to pick up new password..."
kubectl --kubeconfig="${KUBECONFIG}" -n "${NAMESPACE}" rollout restart deployment argocd-server
kubectl --kubeconfig="${KUBECONFIG}" -n "${NAMESPACE}" rollout status deployment argocd-server --timeout=120s

echo ""
echo "==> DONE. New ArgoCD admin password:"
echo "    ${NEW_PASSWORD}"
echo ""
echo "    Store it in your password manager NOW. This will not be shown again."
