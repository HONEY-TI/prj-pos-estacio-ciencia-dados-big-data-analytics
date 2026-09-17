# =========================================================================
# Docker Compose - Makefile
# =========================================================================

SHELL := /bin/bash

COMPOSE := docker compose
INFRA_DIR := infra

CONTAINER_INFRA     := $(INFRA_DIR)/docker-compose.yml
DATANODE_COMPOSE    := $(INFRA_DIR)/datanode/docker-compose.yml
NAMENODE_COMPOSE    := $(INFRA_DIR)/namenode/docker-compose.yml
SPARKMASTER_COMPOSE := $(INFRA_DIR)/spark-master/docker-compose.yml
SPARKWORKER_COMPOSE := $(INFRA_DIR)/spark-worker/docker-compose.yml

DEV_CONTAINER_NAME := rstudio-devcontaier

.PHONY: infra up down prune-volumes clean \
        namenode datanode spark-master spark-worker

# =========================================================================
# Infraestrutura
# =========================================================================

infra: ## Cria rede e volumes da infraestrutura sem iniciar os containers
	$(COMPOSE) -f $(CONTAINER_INFRA) --profile init up --no-start
	@echo "✔ Rede e volumes prontos."

# =========================================================================
# Subida dos serviços
# =========================================================================

up: infra down prune-volumes## Derruba o ambiente anterior e sobe tudo novamente
	@echo "🚀 Subindo NameNode..."
	$(COMPOSE) -f $(NAMENODE_COMPOSE) up -d --build

	@echo "🚀 Subindo DataNode..."
	$(COMPOSE) -f $(DATANODE_COMPOSE) up -d --build

	@echo "🚀 Subindo Spark Master..."
	$(COMPOSE) -f $(SPARKMASTER_COMPOSE) up -d --build

	@echo "🚀 Subindo Spark Worker..."
	$(COMPOSE) -f $(SPARKWORKER_COMPOSE) up -d --build

	@echo ""
	@echo "✔ Todos os containers foram iniciados."
	@echo ""
	@$(COMPOSE) -f $(NAMENODE_COMPOSE) ps
	@$(COMPOSE) -f $(DATANODE_COMPOSE) ps
	@$(COMPOSE) -f $(SPARKMASTER_COMPOSE) ps
	@$(COMPOSE) -f $(SPARKWORKER_COMPOSE) ps

# =========================================================================
# Serviços individuais
# =========================================================================

namenode: infra ## Sobe apenas o NameNode
	$(COMPOSE) -f $(NAMENODE_COMPOSE) up -d --build

datanode: ## Sobe apenas o DataNode
	$(COMPOSE) -f $(DATANODE_COMPOSE) up -d --build

spark-master: ## Sobe apenas o Spark Master
	$(COMPOSE) -f $(SPARKMASTER_COMPOSE) up -d --build

spark-worker: ## Sobe apenas o Spark Worker
	$(COMPOSE) -f $(SPARKWORKER_COMPOSE) up -d --build

# =========================================================================
# Down
# =========================================================================

down: ## Para e remove os containers sem depender de healthcheck
	@echo "🛑 Parando serviços..."

	-$(COMPOSE) -f $(SPARKWORKER_COMPOSE) down --remove-orphans
	-$(COMPOSE) -f $(SPARKMASTER_COMPOSE) down --remove-orphans
	-$(COMPOSE) -f $(DATANODE_COMPOSE) down --remove-orphans
	-$(COMPOSE) -f $(NAMENODE_COMPOSE) down --remove-orphans

	@echo "✔ Serviços parados e removidos."

# =========================================================================
# Limpeza
# =========================================================================

prune-volumes: down ## Remove volumes não utilizados pelo Docker
	@echo "🧹 Removendo volumes não utilizados..."
	-docker volume prune -f
	-docker rm --force rs-network-init 2>/dev/null || true
	-docker rm --force rs-dev-volumes-init 2>/dev/null || true
	-docker rm --force rs-infra 2>/dev/null || true
	@echo "✔ Volumes não utilizados removidos."

clean: down ## Limpeza completa dos containers auxiliares e volumes
	@echo "🧹 Limpando containers auxiliares..."

	-docker rm --force rs-network-init 2>/dev/null || true
	-docker rm --force rs-dev-volumes-init 2>/dev/null || true
	-docker rm --force rs-infra 2>/dev/null || true
	-docker rm --force $(DEV_CONTAINER_NAME) 2>/dev/null || true

	@echo "🧹 Removendo containers com nome 'persona'..."
	-docker ps -aq --filter "name=persona" | xargs -r docker rm --force

	@echo "🧹 Removendo volumes não utilizados..."
	-docker volume prune -f

	@echo "✔ Limpeza concluída."

