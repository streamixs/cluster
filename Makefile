ENV ?= dev
TALOS_DIR := talos/$(ENV)
TF_DIR := terraform
CLUSTER_NAME := streamixs-$(ENV)
TALOS_VERSION ?= v1.12.6
K8S_VERSION   ?= v1.32.0

# Kubeconfig par environnement
ifeq ($(ENV),dev)
  KUBECONFIG := $(HOME)/.talos/kubeconfig-dev
else
  KUBECONFIG := $(HOME)/.talos/kubeconfig-prod
endif


# ============================================================
# Nodes (extraits de talconfig.yaml via yq)
# ============================================================
# Evalue une seule fois par invocation (:= au lieu de =)
TALCONFIG     := $(TALOS_DIR)/talconfig.yaml
ALL_NODES     := $(shell yq -r '.nodes[].ipAddress' $(TALCONFIG) 2>/dev/null | tr '\n' ',' | sed 's/,$$//')
CP_NODES      := $(shell yq -r '.nodes[] | select(.controlPlane == true)  | .ipAddress' $(TALCONFIG) 2>/dev/null | tr '\n' ',' | sed 's/,$$//')
WORKER_NODES  := $(shell yq -r '.nodes[] | select(.controlPlane == false) | .ipAddress' $(TALCONFIG) 2>/dev/null | tr '\n' ',' | sed 's/,$$//')
FIRST_CP      := $(shell yq -r '[.nodes[] | select(.controlPlane == true)][0].ipAddress' $(TALCONFIG) 2>/dev/null)

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

# ============================================================
# Upgrades
# ============================================================

k8s-upgrade-check: ## Dry-run upgrade Kubernetes (K8S_VERSION=v1.x.x)
ifeq ($(ENV),dev)
	@echo "ERREUR: upgrade K8s non supporte sur cluster dev (Docker)"
	@exit 1
endif
	@echo "==> Dry-run upgrade Kubernetes vers $(K8S_VERSION)..."
	talosctl upgrade-k8s --nodes $(FIRST_CP) --to $(subst v,,$(K8S_VERSION)) --dry-run

k8s-upgrade: ## Upgrade Kubernetes (faire k8s-upgrade-check avant)
ifeq ($(ENV),dev)
	@echo "ERREUR: upgrade K8s non supporte sur cluster dev (Docker)"
	@exit 1
endif
	@echo "==> Upgrade Kubernetes vers $(K8S_VERSION) (CP: $(FIRST_CP))..."
	@read -p "As-tu lance 'make k8s-upgrade-check' avant ? Continuer ? [y/N] " ok && [ "$$ok" = "y" ] || exit 1
	talosctl upgrade-k8s --nodes $(FIRST_CP) --to $(subst v,,$(K8S_VERSION))

talos-upgrade-check: ## Dry-run upgrade Talos sur le premier CP (TALOS_VERSION=v1.x.x)
ifeq ($(ENV),dev)
	@echo "ERREUR: upgrade Talos non supporte sur cluster dev (Docker)"
	@exit 1
endif
	@echo "==> Dry-run upgrade Talos vers $(TALOS_VERSION) sur $(FIRST_CP)..."
	talosctl upgrade --nodes $(FIRST_CP) \
		--image ghcr.io/siderolabs/installer:$(TALOS_VERSION) \
		--preserve=true --dry-run

talos-upgrade: ## Upgrade Talos node par node (faire talos-upgrade-check avant)
ifeq ($(ENV),dev)
	@echo "ERREUR: upgrade Talos non supporte sur cluster dev (Docker)"
	@exit 1
endif
	@echo "==> Upgrade Talos vers $(TALOS_VERSION) sur : $(ALL_NODES)"
	@echo "    N'oublie pas: talosVersion a $(TALOS_VERSION) dans $(TALCONFIG) + make talos-gen"
	@read -p "Continuer ? [y/N] " ok && [ "$$ok" = "y" ] || exit 1
	@for node in $$(echo $(ALL_NODES) | tr ',' ' '); do \
		echo "==> Upgrade $$node..."; \
		talosctl upgrade --nodes $$node \
			--image ghcr.io/siderolabs/installer:$(TALOS_VERSION) \
			--preserve=true --wait || exit 1; \
	done
	@echo "==> Upgrade Talos termine."

etcd-backup: ## Snapshot etcd (a faire avant tout upgrade)
ifeq ($(ENV),dev)
	@echo "ERREUR: etcd-backup non supporte sur cluster dev"
	@exit 1
endif
	@mkdir -p backups
	@SNAP=backups/etcd-$(ENV)-$$(date +%Y%m%d-%H%M%S).snapshot && \
		talosctl etcd snapshot $$SNAP --nodes $(FIRST_CP) && \
		echo "==> Snapshot: $$SNAP"


.PHONY: bootstrap cluster cilium argocd talos-gen talos-gen-secret status destroy destroy-argocd help \
        k8s-upgrade-check k8s-upgrade talos-upgrade-check talos-upgrade etcd-backup
