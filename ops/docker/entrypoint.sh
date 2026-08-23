#!/bin/sh
# entrypoint.sh — Configures and starts an ArkConstellation node.
#
# Environment variables:
#   NODE_ROLE          "validator" or "sentry" (required)
#   CHAIN_ID           Cosmos chain ID (default: "arkdevnet_9000-1")
#   VALIDATOR_INDEX    Node index for validators (0, 1, 2, ...)
#   SENTRY_INDEX       Node index for sentries (0, 1, 2, ...)
#   PERSISTENT_PEERS   CometBFT persistent_peers string (required)
#   PRIVATE_PEER_IDS   CometBFT private_peer_ids (sentry only)
#   UNCONDITIONAL_PEER_IDS  CometBFT unconditional_peer_ids (sentry only)
#   MONIKER            Node moniker (default: auto-derived from role+index)
#   PEX                Enable peer exchange: "true" or "false" (default: auto)
#   MIN_GAS_PRICES     Minimum gas prices (default: "0.01esp")
#   PROMETHEUS         Enable Prometheus metrics: "true" or "false" (default: "true")
#   ENABLE_API         Enable Cosmos LCD/API: "true" or "false" (default: "false")
#   ENABLE_EVM_RPC     Enable EVM JSON-RPC: "true" or "false" (default: "false")
#
set -eu

NODE_ROLE="${NODE_ROLE:?NODE_ROLE is required: 'validator' or 'sentry'}"
CHAIN_ID="${CHAIN_ID:-arkdevnet_9000-1}"
MIN_GAS_PRICES="${MIN_GAS_PRICES:-0.01esp}"
PROMETHEUS="${PROMETHEUS:-true}"
ENABLE_API="${ENABLE_API:-false}"
ENABLE_EVM_RPC="${ENABLE_EVM_RPC:-false}"

HOME_DIR="/home/nonroot/.ark"

# Derive node index and moniker from role
if [ "$NODE_ROLE" = "validator" ]; then
    INDEX="${VALIDATOR_INDEX:?VALIDATOR_INDEX required for validator role}"
    MONIKER="${MONIKER:-validator-${INDEX}}"
    NODE_HOME="${HOME_DIR}/node-validator-${INDEX}"
    # Validators: never enable PEX, only talk to their sentry
    PEX="${PEX:-false}"
elif [ "$NODE_ROLE" = "sentry" ]; then
    INDEX="${SENTRY_INDEX:?SENTRY_INDEX required for sentry role}"
    MONIKER="${MONIKER:-sentry-${INDEX}}"
    NODE_HOME="${HOME_DIR}/node-sentry-${INDEX}"
    # Sentries: enable PEX to discover peers, hide validator address
    PEX="${PEX:-true}"
else
    echo "ERROR: NODE_ROLE must be 'validator' or 'sentry', got: '$NODE_ROLE'" >&2
    exit 1
fi

# Initialize node home if not already done
if [ ! -f "${NODE_HOME}/config/config.toml" ]; then
    echo ">>> Initializing ${MONIKER} (${NODE_ROLE}-${INDEX})..."
    arkd init "$MONIKER" \
        --chain-id "$CHAIN_ID" \
        --home "$NODE_HOME" \
        --default-denom esp \
        > /dev/null 2>&1

    # Update config.toml with role-specific settings
    CONFIG="${NODE_HOME}/config/config.toml"

    # Set moniker
    sed -i "s/^moniker = .*/moniker = \"${MONIKER}\"/" "$CONFIG"

    # Set persistent peers
    if [ -n "${PERSISTENT_PEERS:-}" ]; then
        sed -i "s/^persistent_peers = .*/persistent_peers = \"${PERSISTENT_PEERS}\"/" "$CONFIG"
    fi

    # Set PEX
    sed -i "s/^pex = .*/pex = ${PEX}/" "$CONFIG"

    # Sentry-specific: hide validator address from PEX gossip
    if [ "$NODE_ROLE" = "sentry" ]; then
        if [ -n "${PRIVATE_PEER_IDS:-}" ]; then
            sed -i "s/^private_peer_ids = .*/private_peer_ids = \"${PRIVATE_PEER_IDS}\"/" "$CONFIG"
        fi
        if [ -n "${UNCONDITIONAL_PEER_IDS:-}" ]; then
            sed -i "s/^unconditional_peer_ids = .*/unconditional_peer_ids = \"${UNCONDITIONAL_PEER_IDS}\"/" "$CONFIG"
        fi
    fi

    # Prometheus metrics
    if [ "$PROMETHEUS" = "true" ]; then
        sed -i "s/^prometheus = .*/prometheus = true/" "$CONFIG"
        sed -i "s/^prometheus_listen_addr = .*/prometheus_listen_addr = \":9090\"/" "$CONFIG"
    fi

    # Enable API (LCD)
    if [ "$ENABLE_API" = "true" ]; then
        sed -i 's/enable = false/enable = true/' "${NODE_HOME}/config/app.toml" 2>/dev/null || true
    fi

    # Enable EVM JSON-RPC
    if [ "$ENABLE_EVM_RPC" = "true" ]; then
        sed -i 's/enable = false/enable = true/' "${NODE_HOME}/config/app.toml" 2>/dev/null || true
        # EVM JSON-RPC runs on port 8545 by default
        # The cosmos/evm module registers its own JSON-RPC server
    fi

    echo ">>> ${MONIKER} initialized."
fi

# Ensure config is up-to-date (re-apply on every start)
CONFIG="${NODE_HOME}/config/config.toml"
if [ -n "${PERSISTENT_PEERS:-}" ]; then
    sed -i "s/^persistent_peers = .*/persistent_peers = \"${PERSISTENT_PEERS}\"/" "$CONFIG"
fi
sed -i "s/^pex = .*/pex = ${PEX}/" "$CONFIG"

if [ "$NODE_ROLE" = "sentry" ]; then
    [ -n "${PRIVATE_PEER_IDS:-}" ] && \
        sed -i "s/^private_peer_ids = .*/private_peer_ids = \"${PRIVATE_PEER_IDS}\"/" "$CONFIG"
    [ -n "${UNCONDITIONAL_PEER_IDS:-}" ] && \
        sed -i "s/^unconditional_peer_ids = .*/unconditional_peer_ids = \"${UNCONDITIONAL_PEER_IDS}\"/" "$CONFIG"
fi

# Print node info
echo "=== Node Configuration ==="
echo "  Role:       ${NODE_ROLE}"
echo "  Index:      ${INDEX}"
echo "  Moniker:    ${MONIKER}"
echo "  Chain ID:   ${CHAIN_ID}"
echo "  Home:       ${NODE_HOME}"
echo "  PEX:        ${PEX}"
echo "  Prometheus: ${PROMETHEUS}"
echo "=========================="

# Start the node
exec arkd start \
    --home "$NODE_HOME" \
    --minimum-gas-prices "$MIN_GAS_PRICES" \
    --trace \
    "$@"
