ENV ?= dev
TALOS_DIR := talos/$(ENV)
TF_DIR := terraform
CLUSTER_NAME := streamixs-$(ENV)

# Kubeconfig par environnement
ifeq ($(ENV),dev)
  KUBECONFIG := $(HOME)/.talos/kubeconfig-dev
else
  KUBECONFIG := $(HOME)/.talos/kubeconfig-prod
endif

# ============================================================
# Bootstrap complet
# ============================================================

bootstrap: cluster cilium argocd ## Bootstrap complet (cluster + cilium + argocd)

# ============================================================
# Cluster Talos
# ============================================================

cluster: ## Creer le cluster Talos
ifeq ($(ENV),dev)
	@echo "==> Creation du cluster dev (Docker)..."
	talosctl cluster create docker \
		--name $(CLUSTER_NAME) \
		--workers 2 \
		--kubernetes-version v1.35.0 \
		--image ghcr.io/siderolabs/talos:v1.12.0 \
		--memory-controlplanes 4096 \
		--memory-workers 4096 \
		--config-patch @$(TALOS_DIR)/patch.yaml
	@echo "==> Recuperation du kubeconfig..."
	@API_PORT=$$(docker port $(CLUSTER_NAME)-controlplane-1 6443/tcp | cut -d: -f2) && \
		talosctl kubeconfig $(KUBECONFIG) --nodes 10.5.0.2 --force && \
		kubectl config set-cluster $(CLUSTER_NAME) \
			--server=https://127.0.0.1:$$API_PORT \
			--kubeconfig=$(KUBECONFIG)
	@echo "==> Attente que tous les nodes soient Ready..."
	@kubectl --kubeconfig $(KUBECONFIG) wait --for=condition=Ready nodes --all --timeout=300s
	@echo "==> Cluster dev pret."
else
	@echo "==> Application des configs Talos (prod)..."
	@echo "    1. make talos-gen-secret ENV=prod"
	@echo "    2. make talos-gen ENV=prod"
	@echo "    3. talosctl apply-config sur chaque node"
	@echo "    4. talosctl bootstrap sur le premier CP"
	@exit 1
endif

# ============================================================
# Cilium (CNI)
# ============================================================

cilium: ## Installer Cilium via Helm (remplace flannel en dev)
	@echo "==> Installation de Cilium..."
	helm repo add cilium https://helm.cilium.io/ 2>/dev/null || true
	helm repo update cilium
ifeq ($(ENV),dev)
	@echo "==> Suppression de flannel (CNI par defaut)..."
	-kubectl --kubeconfig $(KUBECONFIG) delete daemonset -n kube-system kube-flannel 2>/dev/null
	-kubectl --kubeconfig $(KUBECONFIG) delete configmap -n kube-system kube-flannel-cfg 2>/dev/null
	-kubectl --kubeconfig $(KUBECONFIG) delete serviceaccount -n kube-system flannel 2>/dev/null
	-kubectl --kubeconfig $(KUBECONFIG) delete clusterrole flannel 2>/dev/null
	-kubectl --kubeconfig $(KUBECONFIG) delete clusterrolebinding flannel 2>/dev/null
endif
	helm upgrade --install cilium cilium/cilium \
		--namespace kube-system \
		--kubeconfig $(KUBECONFIG) \
		--version 1.17.1 \
		-f argocd/apps/cilium/values.yaml \
		--wait --timeout 5m
	@echo "==> Cilium installe. Attente des nodes Ready..."
	kubectl --kubeconfig $(KUBECONFIG) wait --for=condition=Ready nodes --all --timeout=300s
	@echo "==> Tous les nodes sont Ready."

# ============================================================
# ArgoCD (Terraform)
# ============================================================

argocd: ## Deployer ArgoCD via Terraform
	@echo "==> Deploiement d'ArgoCD via Terraform..."
	cd $(TF_DIR) && terraform init
	cd $(TF_DIR) && terraform apply -auto-approve -var="kubeconfig=$(KUBECONFIG)"
	@echo "==> ArgoCD deploye."
	@echo ""
	@echo "Mot de passe admin ArgoCD :"
	cd $(TF_DIR) && terraform output argocd_admin_password

# ============================================================
# Talos config generation (talhelper) - prod
# ============================================================

talos-gen: ## Generer les machine configs avec talhelper
	@echo "==> Generation des configs Talos ($(ENV))..."
	cd $(TALOS_DIR) && talhelper genconfig
	@echo "==> Configs generees dans $(TALOS_DIR)/clusterconfig/"

talos-gen-secret: ## Generer et chiffrer les secrets Talos
	@echo "==> Generation des secrets Talos..."
	cd $(TALOS_DIR) && talhelper gensecret > talsecret.sops.yaml
	cd $(TALOS_DIR) && sops -e -i talsecret.sops.yaml
	@echo "==> Secrets generes et chiffres dans $(TALOS_DIR)/talsecret.sops.yaml"

# ============================================================
# Operations
# ============================================================

status: ## Afficher le statut du cluster
	kubectl --kubeconfig $(KUBECONFIG) get nodes -o wide
	@echo ""
	kubectl --kubeconfig $(KUBECONFIG) get pods -A

destroy: ## Detruire le cluster
ifeq ($(ENV),dev)
	@echo "==> Destruction du cluster dev..."
	talosctl cluster destroy --name $(CLUSTER_NAME)
	@talosctl config remove $(CLUSTER_NAME) --noconfirm 2>/dev/null || true
	@rm -f $(KUBECONFIG)
else
	@echo "ERREUR: Destruction du cluster prod non supportee via Makefile"
	@exit 1
endif

destroy-argocd: ## Detruire uniquement ArgoCD (Terraform)
	@echo "==> Destruction d'ArgoCD..."
	cd $(TF_DIR) && terraform destroy -auto-approve -var="kubeconfig=$(KUBECONFIG)"

help: ## Afficher cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: bootstrap cluster cilium argocd talos-gen talos-gen-secret status destroy destroy-argocd help
