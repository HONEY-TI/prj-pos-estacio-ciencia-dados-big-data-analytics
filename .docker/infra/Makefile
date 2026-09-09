CONTAINER_PREFIX := rstudio-
NETWORK := app-network

.PHONY: infra-up infra-down infra-status \
        network volumes \
        spark-master spark-worker namenode datanode \
        clean-devcontainer rebuild-devcontainer

# ============================================================
# Recursos compartilhados
# ============================================================

network:
	@docker network inspect $(NETWORK) >/dev/null 2>&1 || \
		( echo "Criando network $(NETWORK)..."; \
		  docker network create $(NETWORK) )

volumes:
	@docker volume inspect namenode-data >/dev/null 2>&1 || \
		( echo "Criando volume namenode-data..."; \
		  docker volume create namenode-data )

	@docker volume inspect datanode-data >/dev/null 2>&1 || \
		( echo "Criando volume datanode-data..."; \
		  docker volume create datanode-data )

	@docker volume inspect vscode-extensions >/dev/null 2>&1 || \
		( echo "Criando volume vscode-extensions..."; \
		  docker volume create vscode-extensions )

# ============================================================
# Servidores
# ============================================================

spark-master: network
	docker compose -f spark-master/docker-compose.yml up -d

spark-worker: network
	docker compose -f spark-worker/docker-compose.yml up -d

namenode: network volumes
	docker compose -f namenode/docker-compose.yml up -d

datanode: network volumes
	docker compose -f datanode/docker-compose.yml up -d

# ============================================================
# Infraestrutura completa
# ============================================================

infra-up: network volumes
	docker compose -f namenode/docker-compose.yml up -d
	@echo "Aguardando NameNode ficar saudável..."
	@until [ "$$(docker inspect -f '{{.State.Health.Status}}' namenode 2>/dev/null)" = "healthy" ]; do \
		sleep 2; \
	done
	@echo "NameNode saudável."

	docker compose -f datanode/docker-compose.yml up -d
	@echo "Aguardando DataNode ficar saudável..."
	@until [ "$$(docker inspect -f '{{.State.Health.Status}}' datanode 2>/dev/null)" = "healthy" ]; do \
		sleep 2; \
	done
	@echo "DataNode saudável."

	docker compose -f spark-master/docker-compose.yml up -d
	@echo "Aguardando Spark Master ficar saudável..."
	@until [ "$$(docker inspect -f '{{.State.Health.Status}}' spark-master 2>/dev/null)" = "healthy" ]; do \
		sleep 2; \
	done
	@echo "Spark Master saudável."

	docker compose -f spark-worker/docker-compose.yml up -d
	@echo "Aguardando Spark Worker ficar saudável..."
	@until [ "$$(docker inspect -f '{{.State.Health.Status}}' spark-worker 2>/dev/null)" = "healthy" ]; do \
		sleep 2; \
	done
	@echo "Spark Worker saudável."

	@echo ""
	@echo "Infraestrutura compartilhada pronta."

# ============================================================
# Status
# ============================================================

infra-status:
	@echo "=== CONTAINERS ==="
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

	@echo ""
	@echo "=== NETWORK ==="
	@docker network inspect $(NETWORK) \
		--format '{{.Name}}' 2>/dev/null || \
		echo "$(NETWORK) não existe"

	@echo ""
	@echo "=== VOLUMES ==="
	@docker volume inspect namenode-data \
		--format '{{.Name}}' 2>/dev/null || \
		echo "namenode-data não existe"

	@docker volume inspect datanode-data \
		--format '{{.Name}}' 2>/dev/null || \
		echo "datanode-data não existe"

# ============================================================
# Parar servidores
# ============================================================

infra-down:
	docker compose -f spark-worker/docker-compose.yml down
	docker compose -f spark-master/docker-compose.yml down
	docker compose -f datanode/docker-compose.yml down
	docker compose -f namenode/docker-compose.yml down

# ============================================================
# Devcontainer (RStudio) — nome pode variar, mas sempre começa
# com rstudio-, ex: rstudio-devcontainer, rstudio-pos-devcontainer
# ============================================================

clean-devcontainer:
	@matches="$$(docker ps -a --filter "name=^$(CONTAINER_PREFIX)" --format '{{.Names}}')"; \
	if [ -z "$$matches" ]; then \
		echo "Nenhum container '$(CONTAINER_PREFIX)*' encontrado."; \
	else \
		echo "Removendo containers:"; \
		echo "$$matches"; \
		echo "$$matches" | xargs -r docker rm -f; \
	fi
	-yes | docker volume prune
	@echo "Limpeza concluída."

rebuild-devcontainer: clean-devcontainer
	@echo "Pronto para rebuild. Abra o VS Code e rode 'Dev Containers: Rebuild Container'."