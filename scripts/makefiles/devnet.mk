###############################################################################
###                                  Devnet                                 ###
###############################################################################
# Local 4-node (2 validator + 2 sentry) devnet driven by pystarport.
# See networks/devnet/README.md for the full design and how to regenerate
# everything from scratch by hand.

DEVNET_DIR       := networks/devnet
DEVNET_DATA      := $(DEVNET_DIR)/data
DEVNET_VENV      := $(DEVNET_DIR)/.venv-pystarport
DEVNET_CHAIN_ID  := arkdevnet_9000-1
DEVNET_BASE_PORT := 26650
DEVNET_BIN       ?= $(CURDIR)/build/arkd
# node0 (sentry-0) RPC port = base_port + 7 (pystarport's ports.rpc_port offset)
DEVNET_RPC       := http://127.0.0.1:26657
# node0 (sentry-0) EVM JSON-RPC port (only active when manually enabled)
DEVNET_JSON_RPC  := http://127.0.0.1:8545
# node0 (sentry-0) Cosmos LCD/API port (only active when [api] enable=true in app.toml)
DEVNET_API       := http://127.0.0.1:1317

.PHONY: devnet-venv devnet-check-genesis-sync devnet-init devnet-up devnet-down devnet-verify devnet-info devnet-log devnet-explore devnet-clean

devnet-venv:
	@if [ ! -x "$(DEVNET_VENV)/bin/pystarport" ]; then \
		echo ">>> Creating pystarport virtualenv (python3.9 - pystarport pins" \
		     "PyYAML<6, which fails to build from source on Python 3.12+)"; \
		python3.9 -m venv $(DEVNET_VENV); \
		$(DEVNET_VENV)/bin/pip install --quiet --upgrade pip; \
		$(DEVNET_VENV)/bin/pip install --quiet pystarport; \
	fi
	@python3 $(DEVNET_DIR)/patch-pystarport-cli.py $(DEVNET_VENV)

devnet-check-genesis-sync:
	@python3 $(DEVNET_DIR)/check-genesis-sync.py

devnet-init: devnet-venv devnet-check-genesis-sync
	@if [ ! -x "$(DEVNET_BIN)" ]; then \
		echo "!!! DEVNET_BIN not found or not executable: $(DEVNET_BIN)" >&2; \
		echo "    Build/copy the arkd binary there, or set DEVNET_BIN to a release binary path." >&2; \
		exit 1; \
	fi
	@echo ">>> Wiping previous devnet state at $(DEVNET_DATA)"
	@rm -rf $(DEVNET_DATA)
	@mkdir -p $(DEVNET_DATA)
	@echo ">>> pystarport init (4 nodes: sentry-0, validator-0, sentry-1, validator-1)"
	$(DEVNET_VENV)/bin/pystarport init \
		--data $(DEVNET_DATA) \
		--config $(DEVNET_DIR)/pystarport.json \
		--base_port $(DEVNET_BASE_PORT) \
		--cmd $(DEVNET_BIN)
	@echo ">>> Applying sentry-node p2p topology"
	$(DEVNET_VENV)/bin/python $(DEVNET_DIR)/apply-sentry-topology.py \
		$(DEVNET_DATA)/$(DEVNET_CHAIN_ID) $(DEVNET_BIN) $(DEVNET_BASE_PORT)

devnet-up: devnet-init
	@echo ">>> Starting devnet (logs: $(DEVNET_DATA)/devnet.log)"
	$(DEVNET_VENV)/bin/pystarport start --data $(DEVNET_DATA) --quiet \
		> $(DEVNET_DATA)/devnet.log 2>&1 & echo $$! > $(DEVNET_DATA)/pystarport.pid
	@sleep 5
	@if ! kill -0 $$(cat $(DEVNET_DATA)/pystarport.pid) 2>/dev/null; then \
		echo "!!! devnet process died immediately, see $(DEVNET_DATA)/devnet.log"; \
		tail -n 60 $(DEVNET_DATA)/devnet.log; \
		exit 1; \
	fi
	@echo ">>> Devnet running (pid $$(cat $(DEVNET_DATA)/pystarport.pid))."
	@echo ">>> Run 'make devnet-info' for node addresses, 'make devnet-explore' for EVM blocks, 'make devnet-log' to tail logs, 'make devnet-verify' to confirm block production, or 'make devnet-down' to stop."

devnet-verify:
	@$(DEVNET_DIR)/verify-blocks.sh $(DEVNET_RPC)

devnet-info:
	@echo "=== Devnet node status ==="
	@for offset in 0 10 20 30; do \
		base=$$(( $(DEVNET_BASE_PORT) + offset )); \
		rpc=$$(( $(DEVNET_BASE_PORT) + offset + 7 )); \
		echo ""; \
		echo "--- node on base port $$base (RPC http://127.0.0.1:$$rpc) ---"; \
		status=$$(curl -sf -m 2 "http://127.0.0.1:$$rpc/status" 2>/dev/null); \
		if [ -n "$$status" ]; then \
			echo "$$status" | jq -r '"moniker: \(.result.node_info.moniker)\nid: \(.result.node_info.id)\nnetwork: \(.result.node_info.network)\nlisten_addr: \(.result.node_info.listen_addr)\nlatest_block_height: \(.result.sync_info.latest_block_height)\nlatest_block_time: \(.result.sync_info.latest_block_time)"'; \
			curl -sf -m 2 "http://127.0.0.1:$$rpc/net_info" 2>/dev/null | jq -r '"peers: \(.result.n_peers)"' 2>/dev/null || true; \
		else \
			echo "  (not reachable)"; \
		fi; \
	done
	@echo ""
	@echo "=== Staking validators (requires [api] enable=true in app.toml) ==="
	@staking=$$(curl -sf -m 2 "$(DEVNET_API)/cosmos/staking/v1beta1/validators?pagination.limit=10" 2>/dev/null); \
	if [ -n "$$staking" ]; then \
		echo "$$staking" | jq -r '.validators[] | "\(.description.moniker): \(.operator_address) (tokens: \(.tokens))\n  commission: \(.commission.commission_rates.rate)"' 2>/dev/null || echo "  (staking API not reachable — ensure the Cosmos LCD is enabled on node0)"; \
	else \
		echo "  (staking API not reachable — ensure the Cosmos LCD is enabled on node0)"; \
	fi

devnet-log:
	@if [ ! -f "$(DEVNET_DATA)/devnet.log" ]; then \
		echo "!!! $(DEVNET_DATA)/devnet.log not found. Start the devnet first with 'make devnet-up'." >&2; \
		exit 1; \
	fi
	@echo "=== Tailing combined devnet log (Ctrl-C to stop) ==="
	@tail -f $(DEVNET_DATA)/devnet.log

devnet-explore:
	@echo "=== Real-time EVM block explorer (Ctrl-C to stop) ==="
	@$(DEVNET_DIR)/explorer.sh $(DEVNET_JSON_RPC)

devnet-down:
	@if [ -f $(DEVNET_DATA)/pystarport.pid ]; then \
		PID=$$(cat $(DEVNET_DATA)/pystarport.pid); \
		kill $$PID 2>/dev/null || true; \
		sleep 1; \
		pkill -f "arkd.*$(DEVNET_DATA)" 2>/dev/null || true; \
		pkill -f "mantrachaind.*$(DEVNET_DATA)" 2>/dev/null || true; \
		rm -f $(DEVNET_DATA)/pystarport.pid; \
		echo ">>> Devnet stopped."; \
	else \
		echo ">>> No running devnet pid file found ($(DEVNET_DATA)/pystarport.pid)."; \
	fi

devnet-clean: devnet-down
	@rm -rf $(DEVNET_DATA)
	@echo ">>> Devnet data wiped."
