# =========================================================================
# Docker Compose Test - Makefile
# =========================================================================

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

COMPOSE              := docker compose
DATANODE_COMPOSE     := infra/datanode/docker-compose.yml
NAMENODE_COMPOSE     := infra/namenode/docker-compose.yml
SPARKMASTER_COMPOSE  := infra/spark-master/docker-compose.yml
SPARKWORKER_COMPOSE  := infra/spark-worker/docker-compose.yml

NODE_VOLUMES         := datanode-data namenode-data
NETWORKS             := rs-network insights-network helper-network \
                        dotnet-network redis-network dev-network

HEALTH_TIMEOUT       := 300
HEALTH_INTERVAL      := 2

.PHONY: up down prune-clean prune-rstudio

# -------------------------------------------------------------------------
# Aguarda o container ficar healthy.
# Se não houver healthcheck, considera running como suficiente.
# -------------------------------------------------------------------------
define wait_healthy
	@echo "Aguardando $(2)..."; \
	elapsed=0; \
	while (( elapsed < $(HEALTH_TIMEOUT) )); do \
		if ! docker inspect $(1) >/dev/null 2>&1; then \
			echo "❌ Container $(1) não existe mais."; \
			exit 1; \
		fi; \
		state=$$(docker inspect -f '{{.State.Status}}' $(1)); \
		health=$$(docker inspect -f \
			'{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' $(1)); \
		if [[ "$$state" != "running" ]]; then \
			echo "❌ $(2): container está $$state."; \
			exit 1; \
		fi; \
		if [[ "$$health" == "healthy" || "$$health" == "none" ]]; then \
			echo "✅ $(2) pronto (health=$$health)."; \
			exit 0; \
		fi; \
		if [[ "$$health" == "unhealthy" ]]; then \
			echo "❌ $(2) está unhealthy."; \
			exit 1; \
		fi; \
		sleep $(HEALTH_INTERVAL); \
		elapsed=$$((elapsed + $(HEALTH_INTERVAL))); \
	done; \
	echo "❌ Timeout aguardando $(2) após $(HEALTH_TIMEOUT)s."; \
	exit 1
endef

# -------------------------------------------------------------------------
# Inicializa um serviço somente se não estiver saudável.
#
# healthy + running  -> não faz nada.
# starting + running -> aguarda o healthcheck.
# unhealthy          -> tenta reiniciar e aguarda recuperação.
# stopped/ausente    -> docker compose up -d --build.
# Sem healthcheck    -> running é considerado suficiente.
#
# Uso: $(call start_service,container,compose-file,rótulo)
# -------------------------------------------------------------------------
define start_service
	@set -eu; \
	container="$(1)"; \
	compose_file="$(2)"; \
	label="$(3)"; \
	if [[ ! -f "$$compose_file" ]]; then \
		echo "❌ Compose não encontrado: $$compose_file"; \
		exit 1; \
	fi; \
	if docker inspect "$$container" >/dev/null 2>&1; then \
		state=$$(docker inspect -f '{{.State.Status}}' "$$container"); \
		health=$$(docker inspect -f \
			'{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
			"$$container"); \
		if [[ "$$state" == "running" && "$$health" == "healthy" ]]; then \
			echo "✅ $$label já está healthy. Nenhuma ação necessária."; \
		elif [[ "$$state" == "running" && "$$health" == "none" ]]; then \
			echo "✅ $$label está running e não possui healthcheck."; \
		elif [[ "$$state" == "running" && "$$health" == "starting" ]]; then \
			echo "⏳ $$label já está inicializando; aguardando."; \
			$(MAKE) --no-print-directory _wait-healthy \
				CONTAINER="$$container" LABEL="$$label"; \
		elif [[ "$$state" == "running" && "$$health" == "unhealthy" ]]; then \
			echo "⚠️ $$label está unhealthy; tentando reiniciar."; \
			docker restart "$$container" >/dev/null; \
			$(MAKE) --no-print-directory _wait-healthy \
				CONTAINER="$$container" LABEL="$$label" || { \
					echo "⚠️ Reinicialização falhou; recriando pelo Compose."; \
					$(COMPOSE) -f "$$compose_file" up -d --build --force-recreate; \
					$(MAKE) --no-print-directory _wait-healthy \
						CONTAINER="$$container" LABEL="$$label"; \
				}; \
		else \
			echo "🚀 $$label está $$state; iniciando pelo Compose."; \
			$(COMPOSE) -f "$$compose_file" up -d --build; \
		fi; \
	else \
		echo "🚀 $$label não existe; criando pelo Compose."; \
		$(COMPOSE) -f "$$compose_file" up -d --build; \
	fi; \
	if docker inspect "$$container" >/dev/null 2>&1; then \
		$(MAKE) --no-print-directory _wait-healthy \
			CONTAINER="$$container" LABEL="$$label"; \
	fi
endef

# -------------------------------------------------------------------------
# Alvo interno para aguardar um container.
# -------------------------------------------------------------------------
_wait-healthy:
	$(call wait_healthy,$(CONTAINER),$(LABEL))

# -------------------------------------------------------------------------
# Inicialização principal.
# Volumes e redes existentes são preservados pelo Docker Compose.
# -------------------------------------------------------------------------
up:
	$(call start_service,namenode,$(NAMENODE_COMPOSE),NameNode)
	$(call start_service,datanode,$(DATANODE_COMPOSE),DataNode)
	$(call start_service,spark-master,$(SPARKMASTER_COMPOSE),Spark Master)
	$(call start_service,spark-worker,$(SPARKWORKER_COMPOSE),Spark Worker)

	@echo "🟢 Infraestrutura compartilhada pronta."

# -------------------------------------------------------------------------
# Para somente os serviços deste projeto.
# Não remove volumes nem redes externos.
# -------------------------------------------------------------------------
down:
	-$(COMPOSE) -f $(SPARKWORKER_COMPOSE) down
	-$(COMPOSE) -f $(SPARKMASTER_COMPOSE) down
	-$(COMPOSE) -f $(DATANODE_COMPOSE) down
	-$(COMPOSE) -f $(NAMENODE_COMPOSE) down

# -------------------------------------------------------------------------
# Limpeza explícita de recursos não utilizados.
# Atenção: system prune pode afetar outros projetos Docker.
# Não executa automaticamente durante up.
# -------------------------------------------------------------------------
prune-clean:
	@echo "🧹 Limpando recursos não utilizados..."
	docker builder prune -f
	docker system prune -f
	@echo "✅ Limpeza concluída. Volumes não foram podados."

# -------------------------------------------------------------------------
# Limpeza destrutiva explícita.
# -------------------------------------------------------------------------
prune-rstudio: down
	@echo "🗑️ Removendo volumes especificados..."
	-docker volume rm $(NODE_VOLUMES)
	@echo "✅ Limpeza concluída."

