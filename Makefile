#!/bin/bash


##@ Build Dependencies

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

## Tool Binaries
KIND ?= $(LOCALBIN)/kind
KUSTOMIZE ?= $(LOCALBIN)/kustomize

## Tool Versions
KIND_VERSION ?= v0.17.0
KUSTOMIZE_VERSION ?= v4.5.4

.PHONY: kind
kind: $(KIND) ## Download kind locally if necessary.
$(KIND):
	GOBIN=$(LOCALBIN) go install sigs.k8s.io/kind@$(KIND_VERSION)

KUSTOMIZE_INSTALL_SCRIPT ?= "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"
.PHONY: kustomize
kustomize: $(KUSTOMIZE) ## Download kustomize locally if necessary. If wrong version is installed, it will be removed before downloading.
$(KUSTOMIZE): $(LOCALBIN)
	@if test -x $(LOCALBIN)/kustomize && ! $(LOCALBIN)/kustomize version | grep -q $(KUSTOMIZE_VERSION); then \
		echo "$(LOCALBIN)/kustomize version is not expected $(KUSTOMIZE_VERSION). Removing it before installing."; \
		rm -rf $(LOCALBIN)/kustomize; \
	fi
	test -s $(LOCALBIN)/kustomize || { curl -Ss $(KUSTOMIZE_INSTALL_SCRIPT) | bash -s -- $(subst v,,$(KUSTOMIZE_VERSION)) $(LOCALBIN); }

.PHONY: local-setup
local-setup: kind
	./local-setup.sh