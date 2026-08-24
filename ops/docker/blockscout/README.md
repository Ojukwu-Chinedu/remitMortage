# Local Blockscout Explorer for ArkConstellation

This setup deploys a containerized [Blockscout](https://github.com/blockscout/blockscout) instance with PostgreSQL, Redis, smart contract verification, and the Next.js frontend, pre-configured for the ArkConstellation EVM execution layer.

---

## Architecture

* **PostgreSQL (`db`)**: Port `5432` — stores indexed blocks, transactions, receipts, token transfers, logs, and metadata.
* **Redis (`redis`)**: Port `6379` — task queue and caching.
* **Smart Contract Verifier (`smart-contract-verifier`)**: Port `8050` — microservice for compiling and verifying Solidity bytecode.
* **Blockscout Backend / Indexer (`backend`)**: Port `4000` — indexer and API server connected to the Ark node's EVM JSON-RPC (`http://host.docker.internal:8545`).
* **Blockscout Frontend (`frontend`)**: Port `3000` — Next.js responsive block explorer UI.

---

## Quickstart

### 1. Start the Ark Local Devnet
Make sure your local devnet is running and emitting blocks with EVM JSON-RPC active on `127.0.0.1:8545`:

```bash
make devnet-up
```

### 2. Start Blockscout
From the repository root:

```bash
make blockscout-up
```

Or directly using Docker Compose:

```bash
cd ops/docker/blockscout
docker compose up -d
```

### 3. Open Explorer in Browser
* **Frontend UI**: [http://localhost:3000](http://localhost:3000)
* **Backend API / Classic UI**: [http://localhost:4000](http://localhost:4000)
* **API Documentation**: [http://localhost:4000/api-docs](http://localhost:4000/api-docs)
* **Contract Verifier Health**: [http://localhost:8050/health](http://localhost:8050/health)

---

## Configuration & Tuning

Configuration is managed via `.env` in this directory:

| Parameter | Devnet Value | Mainnet Value | Description |
|---|---|---|---|
| `CHAIN_ID` | `9000` | `11199` | EVM Chain ID (matches `EVMChainIDMap`) |
| `COIN` / `COIN_NAME` | `KASH` | `KASH` | Display currency name |
| `DISPLAY_DECIMALS` | `18` | `18` | Native token decimals |
| `NETWORK` | `ArkConstellation Devnet` | `ArkConstellation Mainnet` | Network label |
| `SUBNETWORK` | `arkdevnet_9000-1` | `arkconstellation-1` | Cosmos chain ID |
| `ETHEREUM_JSONRPC_HTTP_URL` | `http://host.docker.internal:8545` | `http://<rpc-host>:8545` | JSON-RPC RPC endpoint |
| `INDEXER_DISABLE_BLOCK_REWARD_FETCHER` | `true` | `true` | Cosmos-SDK EVM does not use standard EVM miner rewards |
| `INDEXER_DISABLE_INTERNAL_TRANSACTIONS_FETCHER` | `true` | `true` | Keep `true` unless `debug_traceTransaction` is enabled on node |
| `NEXT_PUBLIC_NETWORK_RPC_URL` | `http://127.0.0.1:8545` | `https://evm.<domain>` | RPC URL injected into MetaMask on "Add to Wallet" |

---

## Adding ArkConstellation to MetaMask

Blockscout has native Web3 wallet support built into the footer at the bottom of the page and in the top-left network menu.

### Dynamic RPC Handling
Because users may access the explorer locally, over a LAN IP, or via a remote domain, MetaMask requires a browser-reachable RPC URL:

1. **Static Environment Config** (`.env`):
   Set `NEXT_PUBLIC_NETWORK_RPC_URL` to match the public/reachable RPC URL for that environment (e.g. `http://127.0.0.1:8545`, `http://192.168.1.50:8545`, or `https://evm.arkconstellation.io`).

2. **Dynamic / 1-Click Browser Script**:
   If connecting dynamically from any hostname/IP without rebuilding the frontend container, you can execute the following snippet in the browser console (or embed it in a custom dApp/landing page) to dynamically resolve the current host:

   ```javascript
   async function addArkToMetaMask() {
     const rpcUrl = window.location.protocol + "//" + window.location.hostname + ":8545";
     await window.ethereum.request({
       method: "wallet_addEthereumChain",
       params: [{
         chainId: "0x2328", // 9000 (hex)
         chainName: "ArkConstellation Devnet",
         nativeCurrency: {
           name: "KASH",
           symbol: "KASH",
           decimals: 18
         },
         rpcUrls: [rpcUrl],
         blockExplorerUrls: [window.location.origin]
       }]
     });
   }
   ```


---

## Useful Commands

```bash
# View live indexer / backend logs
make blockscout-logs

# View frontend logs
docker compose -f ops/docker/blockscout/docker-compose.yml logs -f frontend

# Stop Blockscout containers
make blockscout-down

# Wipe database and reset indexer data
docker compose -f ops/docker/blockscout/docker-compose.yml down -v
```
