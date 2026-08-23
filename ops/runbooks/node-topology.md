# Multi-Cloud & Multi-Region Node Topology

This runbook defines the production infrastructure topology for ArkConstellation validators and sentries across multiple cloud providers and geographic regions, covering the initial 2-validator setup and the roadmap to scale to 10 validators.

---

## 1. Architecture Overview (Multi-Cloud Sentry Topology)

Every validator signing node runs on an **isolated private subnet with no public IP and no inbound internet route**, communicating solely with its dedicated sentries over a private encrypted link (WireGuard, VPC peering, or Tailscale).

```
                      ┌──────────────────────────────────────────────┐
                      │          Public P2P Gossip & Users           │
                      └───────────────┬──────────────────────────────┘
                                      │
            ┌─────────────────────────┴─────────────────────────┐
            │                                                   │
┌───────────▼───────────────────────────┐   ┌───────────────────▼───────────────────┐
│     Cloud Provider A (e.g., AWS)      │   │     Cloud Provider B (e.g., GCP)      │
│      Region 1 (e.g., us-east-1)       │   │     Region 2 (e.g., europe-west1)     │
│                                       │   │                                       │
│  ┌─────────────────────────────────┐  │   │  ┌─────────────────────────────────┐  │
│  │         Sentry-0 Node           │◄─┼───┼─►│         Sentry-1 Node           │  │
│  │ (Public IP, p2p:26656, rpc:8545)│  │   │  │ (Public IP, p2p:26656, rpc:8545)│  │
│  └────────────────┬────────────────┘  │   │  └────────────────┬────────────────┘  │
│                   │ (Encrypted WireGuard) │                   │ (Encrypted WireGuard)
│  ┌────────────────▼────────────────┐  │   │  ┌────────────────▼────────────────┐  │
│  │        Validator-0 Node         │  │   │  │        Validator-1 Node         │  │
│  │  (NO Public IP, pex=false)      │  │   │  │  (NO Public IP, pex=false)      │  │
│  └────────────────┬────────────────┘  │   │  └────────────────┬────────────────┘  │
│                   │ (Unix socket)     │   │                   │ (Unix socket)     │
│  ┌────────────────▼────────────────┐  │   │  ┌────────────────▼────────────────┐  │
│  │     TMKMS / Hardware Signer     │  │   │  │     TMKMS / Hardware Signer     │  │
│  └─────────────────────────────────┘  │   │  └─────────────────────────────────┘  │
└───────────────────────────────────────┘   └───────────────────────────────────────┘
```

---

## 2. Consensus Quorum & Fault Tolerance (2 vs 10 Validators)

CometBFT (Tendermint BFT) requires a **strict $> 2/3$ (66.7%) voting majority** to propose and commit blocks:

| Metric | 2-Validator Setup (Devnet/Rehearsal) | 10-Validator Setup (Mainnet Target) |
| :--- | :--- | :--- |
| **Stake Distribution** | 50% / 50% | 10% per validator |
| **Required Voting Quorum** | $100\%$ (both must sign) | $\ge 70\%$ ($\ge 7$ validators) |
| **Fault Tolerance ($f = \lfloor(N-1)/3\rfloor$)** | **0 node failures** ($f = 0$) | **Up to 3 node failures** ($f = 3$) |
| **Impact of 1 Node Going Down** | **Chain halts** immediately | **Chain continues seamlessly** |
| **Multi-Cloud Resilience** | If Cloud A fails, network halts | If Cloud A fails (e.g. 2 nodes), 8 nodes remain $\rightarrow$ network produces blocks normally |

---

## 3. Node Configuration Reference

### Validator Node (`node/config/config.toml`)
```toml
# 1. Disable Peer Exchange (never discover or accept untrusted peers)
[p2p]
pex = false
addr_book_strict = false

# 2. Peer EXCLUSIVELY with own sentry node(s)
persistent_peers = "sentry0_id@10.0.1.10:26656"

# 3. Disable all public RPC and REST endpoints
[rpc]
laddr = "tcp://127.0.0.1:26657"
```

### Sentry Node (`sentry/config/config.toml`)
```toml
[p2p]
# 1. Enable PEX so sentry participates in public network discovery
pex = true

# 2. Peer with own validator AND other sentries
persistent_peers = "val0_id@10.0.1.20:26656,sentry1_id@198.51.100.2:26656"

# 3. Hide validator ID from PEX gossip & prevent peer drops under load
private_peer_ids = "val0_id"
unconditional_peer_ids = "val0_id"

# 4. Enable EVM JSON-RPC & Comet RPC for explorer/public traffic (in app.toml)
[json-rpc]
enable = true
address = "0.0.0.0:8545"
```

---

## 4. Scaling from 2 to 10 Validators (Roadmap)

To expand the validator cohort from 2 to 10 independent validators:

1. **Cohort Provisioning**:
   * Recruit 10 distinct entities across at least 3 cloud providers (AWS, GCP, Hetzner, OVH) and 4+ geographic regions (US, Europe, Asia).
2. **Key Ceremony & `gentx` Collection**:
   * Each validator operator initializes their node home and generates a `gentx` self-delegation:
     ```bash
     arkd genesis gentx <key_name> 50000000000000000000000esp \
       --chain-id arkconstellation-1 \
       --moniker "validator-N" \
       --commission-rate 0.05
     ```
   * Eng 2 runs `scripts/genesis/collect-gentx.sh` to validate and assemble all 10 `gentx` files into the canonical `genesis.json`.
3. **Sentry Mesh Tier**:
   * Each of the 10 validator operators deploys $\ge 2$ sentry nodes.
   * Public sentries connect into a distributed P2P mesh across cloud providers.
4. **RPC & Explorer Load Balancing**:
   * Deploy Cloudflare or AWS ALB / GCP Cloud Load Balancing in front of the sentry pool for public `rpc.arkconstellation.io`, `evm.arkconstellation.io`, and `explorer.arkconstellation.io`.
