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
DEVNET_BIN       := $(CURDIR)/build/mantrachaind
# node0 (sentry-0) RPC port = base_port + 7 (pystarport's ports.rpc_port offset)
DEVNET_RPC       := http://127.0.0.1:26657

.PHONY: devnet-venv devnet-check-genesis-sync devnet-init devnet-up devnet-down devnet-verify devnet-clean

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

devnet-init: build devnet-venv devnet-check-genesis-sync
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
	@echo ">>> Run 'make devnet-verify' to confirm block production, or 'make devnet-down' to stop."

devnet-verify:
	@$(DEVNET_DIR)/verify-blocks.sh $(DEVNET_RPC)

devnet-down:
	@if [ -f $(DEVNET_DATA)/pystarport.pid ]; then \
		PID=$$(cat $(DEVNET_DATA)/pystarport.pid); \
		kill $$PID 2>/dev/null || true; \
		sleep 1; \
		pkill -f "mantrachaind.*$(DEVNET_DATA)" 2>/dev/null || true; \
		rm -f $(DEVNET_DATA)/pystarport.pid; \
		echo ">>> Devnet stopped."; \
	else \
		echo ">>> No running devnet pid file found ($(DEVNET_DATA)/pystarport.pid)."; \
	fi

devnet-clean: devnet-down
	@rm -rf $(DEVNET_DATA)
	@echo ">>> Devnet data wiped."
