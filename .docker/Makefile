# =========================================================================
# Docker Compose Test - Makefile
# =========================================================================
SHELL := /bin/bash

COMPOSE              := docker compose
INFRA_DIR            := infra

CONTAINER_INFRA      := $(INFRA_DIR)/docker-compose.yml
DATANODE_COMPOSE     := $(INFRA_DIR)/datanode/docker-compose.yml
NAMENODE_COMPOSE     := $(INFRA_DIR)/namenode/docker-compose.yml
SPARKMASTER_COMPOSE  := $(INFRA_DIR)/spark-master/docker-compose.yml
SPARKWORKER_COMPOSE  := $(INFRA_DIR)/spark-worker/docker-compose.yml

DEV_CONTAINER_NAME   := rstudio-devcontaier
NODE_VOLUMES         := datanode-data namenode-data

.PHONY: up down infra prune-volumes

# ==========================================================ss==
# Infraestrutura completa
# ============================================================
infra: ## Cria network + volumes (profile init), sem iniciar containers de app
	$(COMPOSE) -f $(CONTAINER_INFRA) --profile init up --no-start
	@echo "✔ Rede e volumes prontos."


up: infra down
	-$(COMPOSE) -f $(NAMENODE_COMPOSE) up -d --build 
	@echo "Aguardando NameNode ficar saudável..."
	@until [ "$$(docker inspect -f '{{.State.Health.Status}}' namenode 2>/dev/null)" = "healthy" ]; do \
		sleep 2; \
	done
	@echo "NameNode saudável."

	-$(COMPOSE) -f $(DATANODE_COMPOSE) up -d --build 
	@echo "Aguardando DataNode ficar saudável..."
	@until [ "$$(docker inspect -f '{{.State.Health.Status}}' datanode 2>/dev/null)" = "healthy" ]; do \
		sleep 2; \
	done
	@echo "DataNode saudável."

	-$(COMPOSE) -f $(SPARKMASTER_COMPOSE) up -d --build 
	@echo "Aguardando Spark Master ficar saudável..."
	@until [ "$$(docker inspect -f '{{.State.Health.Status}}' spark-master 2>/dev/null)" = "healthy" ]; do \
		sleep 2; \
	done
	@echo "Spark Master saudável."

	-$(COMPOSE) -f $(SPARKWORKER_COMPOSE) up -d  --build 
	@echo "Aguardando Spark Worker ficar saudável..."
	@until [ "$$(docker inspect -f '{{.State.Health.Status}}' spark-worker 2>/dev/null)" = "healthy" ]; do \
		sleep 2; \
	done
	@echo "Spark Worker saudável."

	-$(COMPOSE) -f $(ROOT_COMPOSE) build

	@echo ""
	@echo

down: prune-volumes
	-$(COMPOSE) -f $(SPARKWORKER_COMPOSE) down
	-$(COMPOSE) -f $(SPARKMASTER_COMPOSE) down
	-$(COMPOSE) -f $(DATANODE_COMPOSE) down
	-$(COMPOSE) -f $(NAMENODE_COMPOSE) down

prune-volumes:
	@echo "Parando e removendo containers..."
	-docker rm --force rs-network-init 2>/dev/null
	-docker rm --force rs-dev-volumes-init 2>/dev/null
	-docker rm --force rs-infra 2>/dev/null
	-docker rm --force $(DEV_CONTAINER_NAME) 2>/dev/null
	-docker ps -aq --filter "name=persona" | xargs -r docker rm --force
	@echo "Removendo volumes..."
	-yes | docker volume prune
	@echo "Limpeza concluída."