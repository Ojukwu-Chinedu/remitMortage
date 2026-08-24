## Summary

Implements all Day 1 deliverables for Track 4 — Infrastructure & Observability. Deploys a 4-node ArkConstellation devnet (2 sentries + 2 validators) in Docker with full monitoring, alerting, and Grafana dashboards.

---

## What's Included

### Node Provisioning (Sentry Architecture)

- **Dockerfile.node** — Multi-stage build: compiles `arkd` from source (Go 1.25, Alpine, musl)
- **setup-devnet.sh** — One-shot init container that generates all validator/sentry keys, genesis with EVM denom metadata, gentxs with unique consensus keys, and resolved peer configs
- **entrypoint.sh** — Node startup script that copies pre-built home, configures RPC binding, P2P peers, Prometheus, EVM RPC, API, and telemetry
- **docker-compose.devnet.yml** — Full stack: init container, 2 sentries (public), 2 validators (private), Prometheus, Grafana, AlertManager, node-exporter

### Monitoring Stack

- **Prometheus** — Scrapes 6 targets: 4 CometBFT nodes, 1 node-exporter, 1 self-monitoring
- **Grafana** — Auto-provisioned with 4 dashboards: Block Production, Validator Health, P2P Health, EVM Gas & Fees
- **AlertManager** — Alert routing with 9 active rules covering chain halts, validator jailing, missed blocks, RPC desync, and system metrics (2 additional rules for EVM/slashing metrics commented out pending upstream fixes)

### Monitoring Runbook

- Architecture diagrams (sentry topology, port table)
- Prometheus, Grafana, AlertManager configuration docs
- Troubleshooting guide for common issues

---

## How to Test

### 1. Start the devnet

```bash
docker compose -f ops/docker/docker-compose.devnet.yml up -d --build
```

Wait ~30 seconds for the init container to complete and nodes to start.

### 2. Verify all containers are running

```bash
docker compose -f ops/docker/docker-compose.devnet.yml ps
```

Expected: 8 containers all "Up" (init exits successfully, 4 nodes healthy, prometheus/grafana/alertmanager running, node-exporter running).

### 3. Check block production

```bash
curl -s http://127.0.0.1:26657/status | jq '.result.sync_info.latest_block_height'
```

Height should be > 0 and increasing. Run twice a few seconds apart to confirm it advances.

### 4. Check second sentry

```bash
curl -s http://127.0.0.1:26677/status | jq '.result.sync_info.latest_block_height'
```

Both sentries should show advancing block heights.

### 5. Verify Prometheus targets

```bash
curl -s http://127.0.0.1:9092/api/v1/targets | jq '.data.activeTargets[] | {instance: .labels.instance, health: .health}'
```

Expected: All 6 targets showing `"health": "up"`.

### 6. Query a balance

```bash
FAUCET=$(docker logs ark-init 2>&1 | grep "faucet:" | head -n 1 | awk '{print $2}')
docker exec ark-sentry-0 arkd q bank balances "$FAUCET" \
  --home /home/nonroot/.ark/node-sentry-0 --node tcp://127.0.0.1:26657
```

Should return the faucet account balance in `esp` (100,000,000 KASH / `100000000000000000000000000esp`).

### 7. Check the validator set

```bash
docker exec ark-sentry-0 arkd q staking validators \
  --home /home/nonroot/.ark/node-sentry-0 --node tcp://127.0.0.1:26657
```

Should show 2 validators with `BOND_STATUS_BONDED`.

### 8. Access Grafana

- Open **http://localhost:3000** in your browser
- Login: `admin` / `arkconstellation`
- Click **Dashboards** then **Browse** then **ArkConstellation** folder
- Verify 4 dashboards are present and showing data

### 9. Access Prometheus

- Open **http://localhost:9092**
- Go to **Status** then **Targets** — all targets should be green/up

### 10. Access AlertManager

- Open **http://localhost:9093**
- Should show the alert routing config

### 11. Check for errors

```bash
docker logs ark-validator-0 2>&1 | grep ERR
docker logs ark-sentry-0 2>&1 | grep ERR
```

Only expected error: "Can't add peer's address to addrbook" (non-fatal, Docker bridge IPs).

### 12. Tear down

```bash
docker compose -f ops/docker/docker-compose.devnet.yml down -v
```

---

## Files Changed

| File | Description |
|------|-------------|
| `ops/docker/Dockerfile.node` | Multi-stage node build |
| `ops/docker/entrypoint.sh` | Node config and startup |
| `ops/docker/setup-devnet.sh` | Genesis init container |
| `ops/docker/docker-compose.devnet.yml` | Full devnet stack |
| `.dockerignore` | Include genesis-template.json |
| `ops/monitoring/prometheus.yml` | Prometheus scrape config |
| `ops/monitoring/alerts/alerts.yml` | 9 active alert rules (2 commented out pending EVM/slashing metrics) |
| `ops/monitoring/alerts/alertmanager.yml` | Alert routing |
| `ops/monitoring/grafana/dashboards/*.json` | 4 Grafana dashboards |
| `ops/monitoring/grafana/provisioning/**` | Grafana auto-provisioning |
| `ops/runbooks/monitoring.md` | Monitoring runbook |

---

## Known Limitations

- **EVM HTTP JSON-RPC** starts then immediately stops (cosmos/evm lifecycle issue). WebSocket works. EVM-specific Prometheus metrics are not available via this endpoint.
- **Multi-region / multi-cloud** — Devnet runs locally in Docker. Production deployment to 2+ regions/providers requires cloud VM provisioning (documented in runbook).
- **node-exporter** reports host-level metrics (Docker host), not per-container metrics.
