.PHONY: lint flake8 help all

# Use bash for inline if-statements in arch_patch target
SHELL:=bash

# Enable BuildKit for Docker build
export DOCKER_BUILDKIT:=1

MAKEPATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PWD := $(dir $(MAKEPATH))

all: lint build

# https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## generate help list
		# @$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# Fichiers/,/^# Base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'
		@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

lint: ## lint dockerfile
		@echo "lint Dockerfile ..."
		@docker run --rm -i hadolint/hadolint < ./Dockerfile

buildnc: ## build container with no cache
		@echo "build image without cache ..."
		@docker buildx build --progress plain --load --no-cache -f Dockerfile  -t edgd1er/transmission-openvpn .


down: ## stop and delete container
		@echo "stop and delete container"
		docker compose -f docker-compose.yml down -v

up: ## start container
		@echo "start container"
		docker compose -f docker-compose.yml up

nordvpnt1: ##test nordvpn api calls
		@echo "test nordvpn api: when no walues, then defaulting is your country +tcp"
		NORDVPN_TESTS=1 DEBUG=false ./app/openvpn/configure-openvpn.sh

nordvpnt2: ##test nordvpn api calls
		@echo "test nordvpn api: Empty category should not prevent api to give an answer."
		NORDVPN_TESTS=2 DEBUG=false ./app/openvpn/configure-openvpn.sh

nordvpnt3: ##test nordvpn api calls
		@echo "test nordvpn api: incompatible criteria should end up in a failure."
		NORDVPN_TESTS=3 DEBUG=false ./app/openvpn/configure-openvpn.sh

nordvpnt4: ##test nordvpn api calls
		@echo "test nordvpn api: when a server name is given, its config gile should be downloaded."
		NORDVPN_TESTS=4 DEBUG=false ./app/openvpn/configure-openvpn.sh