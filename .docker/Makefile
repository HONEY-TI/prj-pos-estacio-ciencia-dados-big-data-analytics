# =========================================================================
# Docker Compose Test - Makefile
# =========================================================================
SHELL := /bin/bash

COMPOSE              := docker compose
RSTUDIO_COMPOSE      := ../.devcontainer/docker-compose.yml
DATANODE_COMPOSE     := infra/datanode/docker-compose.yml
NAMENODE_COMPOSE     := infra/namenode/docker-compose.yml
SPARKMASTER_COMPOSE  := infra/spark-master/docker-compose.yml
SPARKWORKER_COMPOSE  := infra/spark-worker/docker-compose.yml
NODE_VOLUMES         := datanode-data namenode-data

.PHONY: up up-clean prune-clean down prune-rstudio

# Container existe (rodando ou parado)  -> restart
# Não existe                            -> compose up -d --build
# Se o up falhar mas o container passou a existir (criado por outro
# processo durante o build)             -> restart
# uso: $(call start_service,container,compose-file,Rótulo)
define start_service
	@exists() { docker ps -a --format '{{.Names}}' | grep -qx '$(1)'; }; \
	if exists; then \
		status=$$(docker inspect -f '{{.State.Health.Status}}' $(1) 2>/dev/null || true); \
		if [ "$$status" = "healthy" ]; then \
			echo "✅ $(3) já está saudável, nada a fazer."; \
		else \
			echo "⚠️  $(3) está $$status, parando..."; \
			docker stop $(1) >/dev/null || true; \
			echo "🔄 $(3) reiniciando..."; \
			docker restart $(1) >/dev/null || true; \
			status=$$(docker inspect -f '{{.State.Health.Status}}' $(1) 2>/dev/null || true); \
			if [ "$$status" = "unhealthy" ]; then \
				echo "❌ $(3) ficou unhealthy após restart, recriando..."; \
				$(COMPOSE) -f $(2) up -d --build || exit 1; \
			fi; \
		fi; \
	else \
		echo "🚀 $(3) não existe, criando..."; \
		if ! $(COMPOSE) -f $(2) up -d --build; then \
			if exists; then \
				echo "🔄 $(3) foi criado por outro processo, reiniciando..."; \
				docker restart $(1) >/dev/null || exit 1; \
			else \
				exit 1; \
			fi; \
		fi; \
	fi
endef

# Para qualquer container (exceto o dono) que esteja publicando a porta.
# uso: $(call free_port,porta,container-dono)
define free_port
	@for c in $$(docker ps --filter "publish=$(1)" --format '{{.Names}}'); do \
		if [ "$$c" != "$(2)" ]; then \
			echo "⚠️ Porta $(1) em uso por '$$c', parando..."; \
			docker stop "$$c" >/dev/null || true; \
		fi; \
	done
endef

# Espera um container ficar healthy (timeout de 5 min)
# uso: $(call wait_healthy,container,Rótulo)
define wait_healthy
	@echo "Aguardando $(2) ficar saudável..."
	@for i in $$(seq 1 5); do \
		status=$$(docker inspect -f '{{.State.Health.Status}}' $(1) 2>/dev/null); \
		[ "$$status" = "healthy" ] && echo "✅ $(2) saudável." && exit 0; \
		sleep 2; \
	done; \
	echo "Timeout esperando $(2)."; exit 1
endef

define start_rstudio
	$(call free_port,9864,rstudio-pos-devcontainer)
	$(call free_port,8787,rstudio-pos-devcontainer)
	$(call free_port,8888,rstudio-pos-devcontainer)	

	@echo "🔎 Verificando container rstudio-pos-devcontainer..."; \
	if docker inspect rstudio-pos-devcontainer >/dev/null 2>&1; then \
		status=$$(docker inspect -f '{{.State.Status}}' rstudio-pos-devcontainer); \
		echo "📦 Container encontrado: $$status"; \
		if [ "$$status" != "running" ]; then \
			echo "🧹 Removendo container parado..."; \
			docker rm -f rstudio-pos-devcontainer >/dev/null 2>&1 || true; \
		fi; \
	fi

	$(call start_service,rstudio-pos-devcontainer,$(RSTUDIO_COMPOSE))

	echo "🚀 Aguardando RStudio iniciar..."; \
	for i in $$(seq 1 30); do \
		echo ""; \
		echo "🔍 Tentativa $$i/30"; \
		\
		container_status=$$(docker inspect -f '{{.State.Status}}' rstudio-pos-devcontainer 2>/dev/null || echo "missing"); \
		echo "   Container: $$container_status"; \
		\
		if [ "$$container_status" != "running" ]; then \
			echo "❌ Container não está running."; \
			sleep 2; \
			continue; \
		fi; \
		\
		echo "   🔌 Testando RStudio dentro do container..."; \
		if docker exec rstudio-pos-devcontainer \
			sh -c 'curl -fsS --max-time 3 http://127.0.0.1:8787/ >/dev/null 2>&1'; then \
			echo "   ✅ RStudio respondeu dentro do container."; \
			\
			echo "   🌐 Testando porta 8787 pelo host..."; \
			if curl -fsS --max-time 3 http://127.0.0.1:8787/ >/dev/null 2>&1; then \
				echo "   ✅ RStudio respondeu pelo host."; \
				echo ""; \
				echo "✅ RStudio está pronto!"; \
				exit 0; \
			else \
				echo "   ⏳ RStudio funciona no container, mas ainda não responde pelo host."; \
			fi; \
		else \
			echo "   ⏳ RStudio ainda não iniciou na porta 8787 dentro do container."; \
		fi; \
		\
		sleep 2; \
	done; \
	\
	echo ""; \
	echo "❌ RStudio não ficou disponível após 60 segundos."; \
	echo ""; \
	echo "📋 Diagnóstico:"; \
	docker inspect -f 'Container={{.State.Status}} Health={{.State.Health.Status}}' rstudio-pos-devcontainer 2>/dev/null || true; \
	echo ""; \
	echo "🔌 Porta 8787 dentro do container:"; \
	docker exec rstudio-pos-devcontainer sh -c \
		'ss -lntp 2>/dev/null | grep ":8787" || netstat -lntp 2>/dev/null | grep ":8787" || true' \
		2>/dev/null || true; \
	echo ""; \
	echo "📋 Processos RStudio:"; \
	docker exec rstudio-pos-devcontainer sh -c \
		'ps aux | grep "[r]server" || true' \
		2>/dev/null || true; \
	echo ""; \
	echo "📜 Últimos logs:"; \
	docker logs --tail 100 rstudio-pos-devcontainer 2>&1 || true; \
	\
	echo ""; \
	echo "⚠️ Parando somente RStudio..."; \
	docker stop rstudio-pos-devcontainer >/dev/null 2>&1 || true; \
	$(COMPOSE) -f $(RSTUDIO_COMPOSE) down; \
	$(MAKE) prune-clean
endef



up:	
	$(call start_rstudio)

	$(call start_service,namenode,$(NAMENODE_COMPOSE),NameNode)
	$(call wait_healthy,namenode,NameNode)

	$(call start_service,datanode,$(DATANODE_COMPOSE),DataNode)
	$(call wait_healthy,datanode,DataNode)

	$(call start_service,spark-master,$(SPARKMASTER_COMPOSE),Spark Master)
	$(call wait_healthy,spark-master,Spark Master)

	$(call start_service,spark-worker,$(SPARKWORKER_COMPOSE),Spark Worker)
	$(call wait_healthy,spark-worker,Spark Worker)
	
#$(call start_service,rstudio-dev-base,$(RSTUDIO_COMPOSE),RS Studio)
	@echo "🟢 Infraestrutura compartilhada pronta."
#	-exit 0

# Só roda se você chamar explicitamente. Nunca é chamado pelo `up`.
down:
	-$(COMPOSE) -f $(SPARKWORKER_COMPOSE) down
	-$(COMPOSE) -f $(SPARKMASTER_COMPOSE) down
	-$(COMPOSE) -f $(DATANODE_COMPOSE) down
	-$(COMPOSE) -f $(NAMENODE_COMPOSE) down

# Limpeza segura: remove somente recursos não utilizados.
# Não depende do `up`, assim roda mesmo se a infraestrutura falhar.
prune-clean:
	@echo "🧹 Realizando limpeza..."
	-docker builder prune -f
	-docker system prune -f
	-yes | docker volume prune
	@echo "✅ Limpeza concluída."

# Limpeza destrutiva: só roda se chamada explicitamente
prune-rstudio: down
	@echo "🗑️  Parando e removendo containers..."
	@echo "🗑️  Removendo volumes do projeto..."
	-docker volume rm $(NODE_VOLUMES)
	@echo "✅ Limpeza concluída."