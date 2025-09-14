AGE_KEY_FILE = .config/age.agekey
AGE_KEY_SECRET = sops-age
AGE_KEY_NAMESPACE = argocd

.PHONY: create-sops-age
create-sops-age:
	cat $(AGE_KEY_FILE) | oc create secret generic $(AGE_KEY_SECRET) --namespace=$(AGE_KEY_NAMESPACE) \
	--from-file=keys.txt=/dev/stdin