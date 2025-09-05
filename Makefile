SHELL := /usr/bin/bash

KUBE_CONTEXT ?= $(shell kubectl config current-context)

.PHONY: bootstrap deps repos diff status apply-infra apply-media apply-all

bootstrap:
	kubectl apply -f ingress/cluster-issuer.yaml
	helmfile deps

deps:
	helmfile deps

repos:
	helmfile repos

diff:
	helmfile -f helmfiles/infra/helmfile.yaml diff || true
	helmfile -f helmfiles/media/helmfile.yaml diff || true

status:
	helmfile -f helmfiles/infra/helmfile.yaml status || true
	helmfile -f helmfiles/media/helmfile.yaml status || true

apply-infra:
	helmfile -f helmfiles/infra/helmfile.yaml apply

apply-media:
	helmfile -f helmfiles/media/helmfile.yaml apply

apply-all: apply-infra apply-media

