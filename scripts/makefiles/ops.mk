###############################################################################
###                                    Ops                                  ###
###############################################################################
# Infrastructure & Observability tooling (Eng 4)
# Includes local Blockscout explorer, monitoring, and telemetry.

BLOCKSCOUT_DIR := ops/docker/blockscout
BLOCKSCOUT_COMPOSE := $(BLOCKSCOUT_DIR)/docker-compose.yml

.PHONY: blockscout-up blockscout-down blockscout-logs blockscout-status blockscout-clean

blockscout-up:
	@if ! docker info > /dev/null 2>&1; then \
		echo "!!! Docker daemon is not running. Please start Docker Desktop or the docker service first." >&2; \
		exit 1; \
	fi
	@echo ">>> Starting Blockscout explorer containers..."
	docker compose -f $(BLOCKSCOUT_COMPOSE) --env-file $(BLOCKSCOUT_DIR)/.env up -d
	@echo ">>> Blockscout started."
	@echo "    - Frontend: http://localhost:3000"
	@echo "    - Backend / API: http://localhost:4000"
	@echo "    - Verifier: http://localhost:8050"
	@echo ">>> Run 'make blockscout-logs' to follow indexer logs, or 'make blockscout-down' to stop."

blockscout-down:
	@echo ">>> Stopping Blockscout explorer..."
	docker compose -f $(BLOCKSCOUT_COMPOSE) down

blockscout-logs:
	docker compose -f $(BLOCKSCOUT_COMPOSE) logs -f backend frontend

blockscout-status:
	docker compose -f $(BLOCKSCOUT_COMPOSE) ps

blockscout-clean:
	@echo ">>> Stopping Blockscout and wiping database volume..."
	docker compose -f $(BLOCKSCOUT_COMPOSE) down -v
