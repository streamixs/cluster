ENV ?= prod
TALOS_DIR := talos/$(ENV)
TF_DIR := terraform
TALOS_VERSION ?= v1.12.6
K8S_VERSION   ?= v1.35.3

# Un seul environnement permanent: la prod. Le lab de test est jetable
# (kind/k3d) et ne passe jamais par ce Makefile.
ifneq ($(ENV),prod)
$(error ENV=$(ENV) non supporte: seul ENV=prod existe)
endif
KUBECONFIG := $(HOME)/.talos/kubeconfig-prod
AGE_KEY := .config/age.agekey


# ============================================================
# Nodes (extraits de talconfig.yaml via yq)
# ============================================================
# Evalue une seule fois par invocation (:= au lieu de =)
TALCONFIG     := $(TALOS_DIR)/talconfig.yaml
ALL_NODES     := $(shell yq -r '.nodes[].ipAddress' $(TALCONFIG) 2>/dev/null | tr '\n' ',' | sed 's/,$$//')
CP_NODES      := $(shell yq -r '.nodes[] | select(.controlPlane == true)  | .ipAddress' $(TALCONFIG) 2>/dev/null | tr '\n' ',' | sed 's/,$$//')
WORKER_NODES  := $(shell yq -r '.nodes[] | select(.controlPlane == false) | .ipAddress' $(TALCONFIG) 2>/dev/null | tr '\n' ',' | sed 's/,$$//')
FIRST_CP      := $(shell yq -r '[.nodes[] | select(.controlPlane == true)][0].ipAddress' $(TALCONFIG) 2>/dev/null)

# Version Cilium: lue depuis la kustomization qu'ArgoCD applique, jamais
# dupliquee ici. Un pin en dur finit toujours par diverger et `make cilium`
# rejoue alors une ancienne version par-dessus celle deployee par ArgoCD.
CILIUM_KUSTOMIZATION := argocd/apps/cilium/kustomization.yaml
CILIUM_VERSION       := $(shell yq -r '.helmCharts[] | select(.name == "cilium") | .version' $(CILIUM_KUSTOMIZATION) 2>/dev/null)

# ============================================================
# Bootstrap prod (manuel)
# ============================================================

bootstrap: ## Afficher la procedure de bootstrap prod (manuel)
	@echo "==> Bootstrap prod: procedure manuelle"
	@echo "    1. make talos-gen-secret"
	@echo "    2. make talos-gen"
	@echo "    3. talosctl apply-config --nodes <IP> --file $(TALOS_DIR)/clusterconfig/<host>.yaml"
	@echo "    4. talosctl bootstrap --nodes $(FIRST_CP)"
	@echo "    5. make cilium"
	@echo "    6. make argocd"
	@echo "    7. make gitops"
	@echo ""
	@echo "    Voir README.md > Bootstrap prod pour le detail."

# ============================================================
# Cilium (CNI)
# ============================================================

cilium: ## Installer Cilium via Helm
ifeq ($(CILIUM_VERSION),)
	@echo "ERREUR: version Cilium illisible dans $(CILIUM_KUSTOMIZATION)"
	@echo "        (yq installe ? champ .helmCharts[].version present ?)"
	@exit 1
endif
	@echo "==> Installation de Cilium $(CILIUM_VERSION)..."
	helm repo add cilium https://helm.cilium.io/ 2>/dev/null || true
	helm repo update cilium
	helm upgrade --install cilium cilium/cilium \
		--namespace kube-system \
		--kubeconfig $(KUBECONFIG) \
		--version $(CILIUM_VERSION) \
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

gitops: ## Appliquer AppProject + ApplicationSet sur le cluster prod
	kubectl --kubeconfig $(KUBECONFIG) apply -k argocd

# ============================================================
# Talos config generation (talhelper) - prod
# ============================================================

talos-gen: ## Generer les machine configs avec talhelper
	@echo "==> Generation des configs Talos ($(ENV))..."
	cd $(TALOS_DIR) && talhelper genconfig
	@echo "==> Configs generees dans $(TALOS_DIR)/clusterconfig/"

talos-gen-secret: ## Generer et chiffrer les secrets Talos (atomique)
	@echo "==> Generation des secrets Talos..."
	@test -f $(AGE_KEY) || { echo "ERREUR: cle age absente ($(AGE_KEY))"; exit 1; }
	@set -euo pipefail; \
		cd $(TALOS_DIR); \
		tmp=$$(mktemp ./talsecret.XXXXXX); \
		out=$$(mktemp ./talsecret.XXXXXX.sops); \
		trap 'rm -f "$$tmp" "$$out"' EXIT; \
		talhelper gensecret > "$$tmp"; \
		SOPS_AGE_KEY_FILE="$(CURDIR)/$(AGE_KEY)" sops -e "$$tmp" > "$$out"; \
		grep -q 'ENC\[AES256_GCM' "$$out" || { echo "ERREUR: chiffrement SOPS invalide"; exit 1; }; \
		mv "$$out" talsecret.sops.yaml
	@echo "==> Secrets generes et chiffres dans $(TALOS_DIR)/talsecret.sops.yaml"

# ============================================================
# Secrets applicatifs (SOPS)
# ============================================================
# La cle age n'est jamais exportee dans le shell: elle est passee a sops par
# invocation, pour qu'elle ne fuite pas dans l'environnement d'un autre
# process ni dans l'historique.

secret-edit: ## Editer un secret SOPS en place (FILE=chemin/vers/secret.yaml)
ifndef FILE
	@echo "ERREUR: preciser FILE=<chemin>"
	@echo "  ex: make secret-edit FILE=argocd/base/securo/secrets/securo-secret.yaml"
	@exit 1
endif
	@test -f $(AGE_KEY) || { echo "ERREUR: cle age absente ($(AGE_KEY))"; exit 1; }
	@test -f $(FILE) || { echo "ERREUR: fichier absent: $(FILE)"; exit 1; }
	SOPS_AGE_KEY_FILE=$(AGE_KEY) sops $(FILE)
	@echo "==> $(FILE) rechiffre."
	@echo "    Verifier avant commit: make secret-keys FILE=$(FILE)"

secret-keys: ## Lister les cles d'un secret SOPS sans afficher les valeurs (FILE=...)
ifndef FILE
	@echo "ERREUR: preciser FILE=<chemin>"
	@exit 1
endif
	@# Passe par yq et non par un parsing ligne a ligne: sur un bloc litteral
	@# (`cle: |-`), la ligne de la cle ne porte que `|-`, et une mesure naive
	@# annonce 2 caracteres pour une cle PEM de 3000. yq lit la valeur reelle.
	@SOPS_AGE_KEY_FILE=$(AGE_KEY) sops -d $(FILE) \
		| yq -r '(.stringData // .data // {}) | to_entries | .[] \
			| .key + "\t" + ((.value // "") | tostring | length | tostring) \
			+ "\t" + (((.value // "") | tostring | split("\n") | length) | tostring)' \
		| awk -F'\t' '{ \
			d = ($$2 == 0) ? "(vide)" : "<" $$2 " caracteres>"; \
			if ($$3 > 1) d = d " sur " $$3 " lignes"; \
			printf "  %-32s %s\n", $$1, d }'

# ============================================================
# Operations
# ============================================================

status: ## Afficher le statut du cluster
	kubectl --kubeconfig $(KUBECONFIG) get nodes -o wide
	@echo ""
	kubectl --kubeconfig $(KUBECONFIG) get pods -A

destroy-argocd: ## Detruire uniquement ArgoCD (Terraform)
	@echo "==> Destruction d'ArgoCD..."
	cd $(TF_DIR) && terraform destroy -auto-approve -var="kubeconfig=$(KUBECONFIG)"

help: ## Afficher cette aide
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ============================================================
# Upgrades
# ============================================================

k8s-upgrade-check: ## Dry-run upgrade Kubernetes (K8S_VERSION=v1.x.x)
	@echo "==> Dry-run upgrade Kubernetes vers $(K8S_VERSION)..."
	talosctl upgrade-k8s --nodes $(FIRST_CP) --to $(subst v,,$(K8S_VERSION)) --dry-run

k8s-upgrade: ## Upgrade Kubernetes (faire k8s-upgrade-check avant)
	@echo "==> Upgrade Kubernetes vers $(K8S_VERSION) (CP: $(FIRST_CP))..."
	@read -p "As-tu lance 'make k8s-upgrade-check' avant ? Continuer ? [y/N] " ok && [ "$$ok" = "y" ] || exit 1
	talosctl upgrade-k8s --nodes $(FIRST_CP) --to $(subst v,,$(K8S_VERSION))

talos-upgrade-check: ## Dry-run upgrade Talos sur le premier CP (TALOS_VERSION=v1.x.x)
	@echo "==> Dry-run upgrade Talos vers $(TALOS_VERSION) sur $(FIRST_CP)..."
	talosctl upgrade --nodes $(FIRST_CP) \
		--image ghcr.io/siderolabs/installer:$(TALOS_VERSION) \
		--preserve=true --dry-run

talos-upgrade: ## Upgrade Talos node par node (faire talos-upgrade-check avant)
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
	@mkdir -p backups
	@SNAP=backups/etcd-$(ENV)-$$(date +%Y%m%d-%H%M%S).snapshot && \
		talosctl etcd snapshot $$SNAP --nodes $(FIRST_CP) && \
		echo "==> Snapshot: $$SNAP"


.PHONY: bootstrap cilium argocd gitops talos-gen talos-gen-secret status destroy-argocd help \
        k8s-upgrade-check k8s-upgrade talos-upgrade-check talos-upgrade etcd-backup
