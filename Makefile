.PHONY: list
list:
	@echo "Targets:"	
	@LC_ALL=C $(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/(^|\n)# Files(\n|$$)/,/(^|\n)# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'
	@echo

	

.ONESHELL:
SHELL := /bin/bash

export INVENTORY=-i hosts-berg.yml
export

deploy:
	ansible-playbook ${INVENTORY} ansible/deploy.yml

deploy-nodes:
	ansible-playbook ${INVENTORY} ansible/deploy.yml --tags=set-nodes

deploy-kuber:
	ansible-playbook ${INVENTORY} ansible/deploy.yml --tags=kuber

deploy-kuber-storage:
	ansible-playbook ${INVENTORY} ansible/deploy.yml --tags=kuber-storage

deploy-cert-manager:
	ansible-playbook ${INVENTORY} ansible/deploy.yml --tags=cert-manager

deploy-os-security:
	ansible-playbook ${INVENTORY} ansible/deploy.yml --tags=os-security

deploy-os-network:
	ansible-playbook ${INVENTORY} ansible/deploy.yml --tags=os-network

deploy-os-release:
	ansible-playbook ${INVENTORY} ansible/deploy.yml --tags=os-release
	
	
deploy-opensearch:
	ansible-playbook ${INVENTORY} ansible/deploy.yml --tags=opensearch

deploy-fluent-bit:
	ansible-playbook ${INVENTORY} ansible/deploy.yml --tags=fluent-bit
	

copy-files:
	ansible-playbook ansible/deploy.yml -i hosts.yml --tags=copy-files
	
