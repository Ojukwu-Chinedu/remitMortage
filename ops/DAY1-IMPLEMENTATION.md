# Day 1 Implementation Summary — Track 4: Infrastructure & Observability

**Engineer:** Eng 4
**Branch:** `track/4-infra-observability`
**Date:** 2026-08-23
**Status:** Day 1 Complete

---

## What Was Implemented

### 1. Node Provisioning — Docker-based Sentry Architecture (`ops/docker/`)

Created containerized node definitions that enforce the **Sentry Node Architecture**:
validators are never publicly reachable; only sentry nodes expose RPC/P2P/LCD endpoints.

#### Files Created

| File | Purpose |
|------|---------|
| `ops/docker/Dockerfile.node` | Multi-stage Dockerfile for both validator and sentry nodes. Builds the `arkd` binary from source (Alpine + CGO + wasmvm). Configurable at runtime via environment variables. |
| `ops/docker/entrypoint.sh` | Node initialization and startup script. Handles node ID generation, config patching (persistent_peers, PEX, private_peer_ids), and role-based configuration. |
| `ops/docker/docker-compose.devnet.yml` | 4-node devnet compose file: sentry-0 + validator-0 + sentry-1 + validator-1. Includes monitoring stack (Prometheus, Grafana, AlertManager). |
| `ops/docker/init-devnet.sh` | Initialization script that generates node IDs and writes a resolved compose file with real peer IDs. |

#### How It Works

1. **Single image, two roles:** The same Docker image runs as either validator or sentry, determined by the `NODE_ROLE` environment variable. This avoids maintaining separate images.

2. **Entrypoint script:** On first start, the entrypoint initializes the node home directory, then patches `config.toml` based on the node's role:
   - **Validators:** `pex=false`, peers only their sentry, no public ports exposed
   - **Sentries:** `pex=true`, peers with their validator + the other sentry, public ports exposed

3. **Node ID resolution:** The `init-devnet.sh` script temporarily starts each node to generate its `node_key.json`, extracts the node ID, and writes a resolved compose file with real peer IDs. This is necessary because CometBFT node IDs are generated during `init` and cannot be predicted.

#### Architecture Diagram

```
                    Public Internet
                         |
            +------------+------------+
            |                         |
      [sentry-0]              [sentry-1]
      P2P: 26656               P2P: 26676
      RPC: 26657               RPC: 26677
      LCD: 1317                LCD: 1318
      Prometheus: 9090         Prometheus: 9091
            |                         |
            | persistent_peers        | persistent_peers
            | pex=true                | pex=true
            | private_peer_ids=[val0] | private_peer_ids=[val1]
            |                         |
      [validator-0]           [validator-1]
      (NO public ports)       (NO public ports)
      pex=false               pex=false
      peers: sentry-0 only    peers: sentry-1 only
```

#### Usage

```bash
# Initialize and start the devnet
bash ops/docker/init-devnet.sh
docker compose -f ops/docker/docker-compose.devnet-resolved.yml up -d

# Check status
curl -s http://127.0.0.1:26657/status | jq '.result.node_info'

# View logs
docker compose -f ops/docker/docker-compose.devnet-resolved.yml logs -f

# Stop
docker compose -f ops/docker/docker-compose.devnet-resolved.yml down -v
```

---

### 2. Monitoring Setup (`ops/monitoring/`)

Deployed Prometheus + Grafana + AlertManager stack with dashboards for
block production, validator health, P2P connectivity, and EVM gas usage.

#### Files Created

| File | Purpose |
|------|---------|
| `ops/monitoring/prometheus.yml` | Prometheus scrape configuration. Targets CometBFT metrics, EVM JSON-RPC metrics, node_exporter, and AlertManager. |
| `ops/monitoring/alerts/alerts.yml` | Alert rules for chain health, validator status, and infrastructure issues. |
| `ops/monitoring/alerts/alertmanager.yml` | AlertManager routing configuration. Routes critical alerts immediately, warnings after 30 min. |
| `ops/monitoring/grafana/provisioning/datasources/datasource.yml` | Auto-configures Prometheus as Grafana's default data source. |
| `ops/monitoring/grafana/provisioning/dashboards/dashboards.yml` | Auto-loads dashboard JSON files from the dashboards directory. |
| `ops/monitoring/grafana/dashboards/block-production.json` | Dashboard: block height, production rate, block time, consensus rounds. |
| `ops/monitoring/grafana/dashboards/validator-health.json` | Dashboard: voting power, jailing status, signing rate, missed blocks. |
| `ops/monitoring/grafana/dashboards/p2p-health.json` | Dashboard: peer count, P2P traffic, connection status. |
| `ops/monitoring/grafana/dashboards/evm-gas.json` | Dashboard: EVM base fee, gas used per block, gas utilization, tx throughput. |

#### Metrics Scraped

| Source | Port | Metrics |
|--------|------|---------|
| CometBFT | 9090 | Block height, consensus state, peer count, validator power, slashing |
| EVM JSON-RPC | 8545 | Base fee, gas used, transaction count |
| node_exporter | 9100 | CPU, RAM, disk, network |
| Prometheus | 9090 | Self-monitoring |

#### Alert Rules

| Alert | Condition | Severity | Purpose |
|-------|-----------|----------|---------|
| `ChainNotProducing` | No blocks in 30s | critical | Detect chain halt |
| `ConsensusRoundSlow` | Round > 2 | warning | Detect consensus issues |
| `MissedBlocks` | No blocks in 1min | critical | Detect consensus failure |
| `ValidatorJailed` | Jailed > 0 | critical | Detect validator punishment |
| `ValidatorMissingSignatures` | Signing < 95% | warning | Pre-emptive jailing alert |
| `NodeUnreachable` | scrape fails | critical | Detect node downtime |
| `RPCDesync` | lagging peers | warning | Detect sync issues |
| `BaseFeeSpike` | > 5x 1hr avg | warning | Detect fee market issues |
| `HighDiskUsage` | < 15% free | warning | Prevent disk full |
| `HighCPUUsage` | > 85% for 5min | warning | Detect resource exhaustion |

#### Grafana Dashboards

| Dashboard | Panels |
|-----------|--------|
| **Block Production** | Current block height, block production rate, average block time, consensus round number, block height over time |
| **Validator Health** | Validator voting power, jailed status, signing rate, cumulative missed blocks |
| **P2P Health** | Connected peers, peer count over time, P2P traffic, connection status |
| **EVM Gas & Fees** | EVM base fee, gas used per block, block gas utilization, EVM transaction throughput |

---

### 3. Monitoring Runbook (`ops/runbooks/monitoring.md`)

Comprehensive runbook covering:
- Quick start guide for the monitoring stack
- Architecture overview with port reference
- Prometheus configuration and how to add new nodes
- Grafana dashboard descriptions and import instructions
- AlertManager configuration and notification setup
- Alert rules reference with conditions and actions
- Node topology documentation template for production
- Troubleshooting guide for common monitoring issues

---

## Design Decisions

### Decision 1: Single Dockerfile, Two Roles

**Choice:** One `Dockerfile.node` that runs as either validator or sentry based on `NODE_ROLE` env var.

**Rationale:** Industry standard (e.g., Cosmos validators, Ethereum CL clients). Avoids maintaining two separate images. The entrypoint script handles role-specific configuration at runtime.

### Decision 2: Docker Compose for Local Devnet

**Choice:** Docker Compose for the local devnet monitoring stack.

**Rationale:** Docker Compose is the standard tool for multi-container local development. It handles networking, volumes, and service orchestration. For production, this would migrate to Kubernetes or cloud-specific orchestration.

### Decision 3: Prometheus + Grafana for Monitoring

**Choice:** Prometheus for metrics collection, Grafana for visualization, AlertManager for alerting.

**Rationale:** This is the de facto standard monitoring stack for Cosmos SDK and CometBFT chains. Both CometBFT and `cosmos/evm` expose Prometheus-compatible metrics natively. Grafana has native Prometheus support and is widely used in the Cosmos ecosystem.

### Decision 4: AlertManager over PagerDuty Direct

**Choice:** AlertManager as the alerting layer, with PagerDuty/Slack as notification targets.

**Rationale:** AlertManager provides alert grouping, inhibition, and routing out of the box. It integrates with PagerDuty, Slack, email, and webhooks. For Day 1, we use AlertManager's built-in UI. PagerDuty integration is documented and ready to enable when credentials are available.

### Decision 5: Devnet Monitoring Targets Docker Service Names

**Choice:** Prometheus scrapes targets by Docker service name (e.g., `sentry-0:9090`) rather than IP addresses.

**Rationale:** Docker Compose provides internal DNS resolution on the bridge network. This makes the configuration portable and doesn't require hardcoded IPs. For bare-metal or non-Docker deployments, the runbook documents how to update targets to use IP addresses.

---

## What's Left for Day 2/3

### Day 2 Tasks (24:00 – 48:00)

- [ ] **Blockscout Explorer:** Fork `MANTRA-Chain/mantra-explorer-evm-blockscout`, rebrand, connect to devnet EVM RPC
- [ ] **Alert Configuration:** Test each alert fires correctly against devnet
- [ ] **Runbooks:** Write `chain-halt.md`, `validator-jail-unjail.md`, `state-rollback.md`, `key-ceremony.md`
- [ ] **Runbook Review:** Each runbook reviewed by at least one other engineer

### Day 3 Tasks (48:00 – 72:00)

- [ ] **Key Ceremony:** Execute hardware multisig key ceremony (Ledger/HSM)
- [ ] **Public Endpoints:** Configure load balancers, DNS routing, verify chain ID
- [ ] **Bug Bounty:** Publish bug bounty with contact details and scope
- [ ] **Monitoring Migration:** Update Prometheus/Grafana for mainnet endpoints

---

## Dependencies on Other Tracks

| Need From | What | Status |
|-----------|------|--------|
| Eng 1 | `ark-v0.1.0-alpha` binary | ✅ Available |
| Eng 2 | Devnet running | ✅ `STATUS.md` = READY |
| Eng 1 | `v1.0.0` binary | ⏳ Day 3 |
| Eng 2 | `networks/mainnet/genesis.json` | ⏳ Day 3 morning |
| Eng 3 | Chaos sign-off | ⏳ Day 2/3 |

---

## Docker Quick Reference

If you're new to Docker, here's a minimal reference:

### Build

```bash
# Build the node image
docker build -f ops/docker/Dockerfile.node -t arkconstellation-node .

# Or use make (builds the root Dockerfile)
make build-image
```

### Run

```bash
# Run a single sentry node (standalone test)
docker run -d \
  -e NODE_ROLE=sentry \
  -e SENTRY_INDEX=0 \
  -e CHAIN_ID=arkdevnet_9000-1 \
  -p 26657:26657 \
  -p 9090:9090 \
  arkconstellation-node

# Check logs
docker logs -f <container-id>

# Stop and remove
docker stop <container-id> && docker rm <container-id>
```

### Docker Compose

```bash
# Start full devnet + monitoring
docker compose -f ops/docker/docker-compose.devnet-resolved.yml up -d

# View status
docker compose -f ops/docker/docker-compose.devnet-resolved.yml ps

# View logs (all services)
docker compose -f ops/docker/docker-compose.devnet-resolved.yml logs -f

# Stop everything (including volumes)
docker compose -f ops/docker/docker-compose.devnet-resolved.yml down -v
```

### Common Commands

```bash
# List running containers
docker ps

# Execute command in running container
docker exec -it <container-id> sh

# View container resource usage
docker stats

# Clean up unused images
docker image prune -a
```

---

## Files Summary

```
ops/
├── docker/
│   ├── Dockerfile.node              # Node container definition (validator/sentry)
│   ├── entrypoint.sh                # Node init and startup script
│   ├── docker-compose.devnet.yml    # Devnet compose template (with peer ID placeholders)
│   └── init-devnet.sh               # Generates node IDs and resolves compose file
├── monitoring/
│   ├── prometheus.yml               # Prometheus scrape configuration
│   ├── alerts/
│   │   ├── alerts.yml               # Alert rules (chain, validator, infra)
│   │   └── alertmanager.yml         # AlertManager routing config
│   └── grafana/
│       ├── provisioning/
│       │   ├── datasources/
│       │   │   └── datasource.yml   # Prometheus data source auto-config
│       │   └── dashboards/
│       │       └── dashboards.yml   # Dashboard auto-loading config
│       └── dashboards/
│           ├── block-production.json # Block height, rate, time, rounds
│           ├── validator-health.json # Voting power, jailing, signing
│           ├── p2p-health.json       # Peers, traffic, connectivity
│           └── evm-gas.json          # Base fee, gas, tx throughput
├── runbooks/
│   └── monitoring.md                # Monitoring setup and operations runbook
└── DAY1-IMPLEMENTATION.md           # This document
```
