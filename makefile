SHELL := /bin/bash

default: help;
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))
ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
COMMIT_SHA_SHORT ?= $(shell git rev-parse --short=12 HEAD)

#==========================================================================================
##@ Docker
#==========================================================================================
docker-build: ## build a snapshot release within docker
	@docker build ./ -t docmost:${COMMIT_SHA_SHORT} -f ./Dockerfile

check_env: # check for needed envs
ifndef GITHUB_USER
	$(error GITHUB_USER is undefined, set it to your GitHub username, e.g., make docker-login GITHUB_USER=myusername GITHUB_TOKEN=...)
endif
ifndef GITHUB_TOKEN
	$(error GITHUB_TOKEN is undefined, create one with repo permissions here: https://github.com/settings/tokens/new?scopes=repo,write%3Apackages)
endif

docker-login: check_env ## Login to the GH docker registry using your own access token (idempotent)
	@echo ">> Checking if already logged in to ghcr.io..."
	@if grep -q '"ghcr.io"' $$HOME/.docker/config.json 2>/dev/null; then \
		echo ">> Already logged in to ghcr.io"; \
	else \
		echo ">> Logging in to GitHub Container Registry (ghcr.io) as ${GITHUB_USER}..."; \
		echo "${GITHUB_TOKEN}" | docker login ghcr.io -u "${GITHUB_USER}" --password-stdin; \
		echo ">> Login successful!"; \
	fi

docker-logout:
	@echo ">> Logging out from GitHub Container Registry (ghcr.io)..."
	@docker logout ghcr.io
	@echo ">> Logged out successfully."

docker-check-login:
	@echo ">> Checking if logged in to ghcr.io..."
	@if grep -q '"ghcr.io"' $$HOME/.docker/config.json 2>/dev/null; then \
		echo ">> You are logged in to ghcr.io"; \
	else \
		echo ">> ERROR: You are NOT logged in to ghcr.io"; \
		echo ">> Please run 'make docker-login GITHUB_USER=youruser GITHUB_TOKEN=yourtoken' to login"; \
		exit 1; \
	fi


docker-push: docker-check-login docker-build ## build and push the docker image to GH registry







release: check_env check-branch check-git-clean verify ## release a new version, call with version="v1.2.3", make sure to have valid GH token
	@[ "${version}" ] || ( echo ">> version is not set, mausage: make release version=\"v1.2.3\" "; exit 1 )
	@git tag -d $(version) || true
	@git tag -a $(version) -m "Release version: $(version)"
	@git push --delete origin $(version) || true
	@git push origin $(version) || true
	@goreleaser release --clean






.PHONY: check-git-clean
check-git-clean: # check if git repo is clen
	@git diff --quiet

.PHONY: check-branch
check-branch:
	@current_branch=$$(git symbolic-ref --short HEAD) && \
	if [ "$$current_branch" != "main" ]; then \
		echo "Error: You are on branch '$$current_branch'. Please switch to 'main'."; \
		exit 1; \
	fi



help: ## Show this help
	@egrep '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST)  | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m·%-20s\033[0m %s\n", $$1, $$2}'