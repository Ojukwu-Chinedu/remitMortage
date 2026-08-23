#!/usr/bin/env bash
# init-devnet.sh — Initialize the 4-node devnet and resolve peer IDs.
#
# This script:
#   1. Builds the Docker image
#   2. Temporarily starts each node to generate its node_key.json
#   3. Extracts the node IDs
#   4. Writes a resolved docker-compose.devnet-resolved.yml with real peer IDs
#
# Usage:
#   bash ops/docker/init-devnet.sh
#
# After running this, start the devnet with:
#   docker compose -f ops/docker/docker-compose.devnet-resolved.yml up -d

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_TEMPLATE="${SCRIPT_DIR}/docker-compose.devnet.yml"
COMPOSE_RESOLVED="${SCRIPT_DIR}/docker-compose.devnet-resolved.yml"
BUILD_CONTEXT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "=== ArkConstellation Devnet Initialization ==="
echo ""

# Step 1: Build the Docker image
echo ">>> Step 1: Building Docker image..."
docker build \
    -f "${SCRIPT_DIR}/Dockerfile.node" \
    -t arkconstellation-node:latest \
    "${BUILD_CONTEXT}"
echo "    Image built: arkconstellation-node:latest"
echo ""

# Step 2: Generate node IDs by temporarily starting each node
echo ">>> Step 2: Generating node IDs..."

generate_node_id() {
    local name="$1"
    local output
    output=$(docker run --rm --entrypoint sh arkconstellation-node:latest \
        -c "arkd init temp-node --chain-id temp --home /tmp/temp-home >/dev/null 2>&1 && arkd comet show-node-id --home /tmp/temp-home" \
        2>/dev/null)
    echo "$output"
}

echo "    Generating sentry-0 node ID..."
SENTRY_0_ID=$(generate_node_id "sentry-0")
echo "    sentry-0: ${SENTRY_0_ID}"

echo "    Generating validator-0 node ID..."
VALIDATOR_0_ID=$(generate_node_id "validator-0")
echo "    validator-0: ${VALIDATOR_0_ID}"

echo "    Generating sentry-1 node ID..."
SENTRY_1_ID=$(generate_node_id "sentry-1")
echo "    sentry-1: ${SENTRY_1_ID}"

echo "    Generating validator-1 node ID..."
VALIDATOR_1_ID=$(generate_node_id "validator-1")
echo "    validator-1: ${VALIDATOR_1_ID}"
echo ""

# Step 3: Create resolved docker-compose with real node IDs
echo ">>> Step 3: Writing resolved docker-compose..."

sed \
    -e "s/VALIDATOR_0_ID/${VALIDATOR_0_ID}/g" \
    -e "s/VALIDATOR_1_ID/${VALIDATOR_1_ID}/g" \
    -e "s/SENTRY_0_ID/${SENTRY_0_ID}/g" \
    -e "s/SENTRY_1_ID/${SENTRY_1_ID}/g" \
    "${COMPOSE_TEMPLATE}" > "${COMPOSE_RESOLVED}"

echo "    Written: ${COMPOSE_RESOLVED}"
echo ""

# Step 4: Print summary
echo "=== Node IDs ==="
echo "  sentry-0:      ${SENTRY_0_ID}"
echo "  validator-0:    ${VALIDATOR_0_ID}"
echo "  sentry-1:      ${SENTRY_1_ID}"
echo "  validator-1:    ${VALIDATOR_1_ID}"
echo ""
echo "=== Next Steps ==="
echo "  1. Start the devnet:"
echo "     docker compose -f ops/docker/docker-compose.devnet-resolved.yml up -d"
echo ""
echo "  2. Check node status:"
echo "     curl -s http://127.0.0.1:26657/status | jq '.result.node_info'"
echo ""
echo "  3. View logs:"
echo "     docker compose -f ops/docker/docker-compose.devnet-resolved.yml logs -f"
echo ""
echo "  4. Access monitoring:"
echo "     Grafana:       http://localhost:3000 (admin / arkconstellation)"
echo "     Prometheus:    http://localhost:9092"
echo "     AlertManager:  http://localhost:9093"
echo ""
echo "  5. Stop the devnet:"
echo "     docker compose -f ops/docker/docker-compose.devnet-resolved.yml down -v"
