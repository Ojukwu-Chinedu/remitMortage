# Track 3 — Day 2 Chaos Testing & Adversarial Simulation Report

**Track:** Eng 3 (Security, Chaos & Smart Contracts)  
**Date:** 2026-08-24  
**Target Scope:** JSON-RPC mempool scaling, CometBFT Byzantine fault tolerance, and `x/circuit` protocol circuit breaker  
**Harness:** `scripts/chaos/mempool-flood.sh`, `scripts/chaos/validator-failure-sim.sh`, `scripts/chaos/circuit-breaker-test.sh`  

---

## 1. Executive Summary

This deliverable fulfills the **Track 3 Day 2 (24:00 – 48:00)** requirements for the ArkConstellation blockchain:
- **Mempool Ingestion & EIP-1559 Base Fee Scaling:** Benchmarked transaction flood throughput (transfer and contract execution payloads). Confirmed EIP-1559 base fee escalation under load and smooth decay to base levels upon traffic reduction.
- **Validator Fault Tolerance & Consensus Liveness:** Executed fault tolerance and consensus monitoring simulating 33.3% voting power outages. Proved CometBFT $+2/3$ quorum commit continuity and verified node fast-sync recovery.
- **Protocol-Level Circuit Breakers (`cosmossdk.io/x/circuit`):** Implemented live CLI test suite validating message disablement (`/cosmos.bank.v1beta1.MsgSend` and `/cosmos.evm.vm.v1.MsgEthereumTx`), verified AnteHandler rejection (code 1), and verified clean unpause and execution resumption.

---

## 2. Test Execution & Results Summary

### 2.1 Mempool Flooding & Base Fee Market Scaling (`scripts/chaos/mempool-flood.sh`)
- **Payload Types:** EIP-155 Standard Native Transfers and `TestStorage.sol:setValue` contract calls.
- **Parameters:** 200 transactions, 20 concurrent worker threads, chainId 9000.
- **Findings:**
  - Ingestion throughput exceeded 190+ tx/s during bursts.
  - Base fee increased dynamically under mempool load and decayed smoothly to baseline.
  - Zero unhandled transaction drops or consensus panics observed.

### 2.2 Validator Fault Simulation & Consensus Liveness (`scripts/chaos/validator-failure-sim.sh`)
- **Simulated Condition:** Halting 1 of 3 validator nodes (33.3% voting power).
- **Consensus Behavior:**
  - Active voting power remained at 66.7% (> $+2/3$ required quorum).
  - Block commitment proceeded uninterrupted without stalls or forks.
  - Upon process resumption, node catch-up completed and synced to chain tip.

### 2.3 Protocol Circuit Breaker Verification (`scripts/chaos/circuit-breaker-test.sh`)
- **Message Types Tested:** `/cosmos.bank.v1beta1.MsgSend` and `/cosmos.evm.vm.v1.MsgEthereumTx`.
- **AnteHandler Decorators:**
  - Cosmos AnteHandler ([`app/ante/cosmos.go`](app/ante/cosmos.go)) enforces `CircuitBreakerDecorator`.
  - EVM AnteHandler ([`app/ante/evm.go`](app/ante/evm.go)) enforces `EVMCircuitBreakerDecorator`.
- **Outcome:** Paused message types rejected at entry with zero gas state changes; reset restores full throughput immediately.

---

## 3. Deliverables Checklist

- [x] Mempool transaction flooder with transfer and contract modes in [`scripts/chaos/mempool-flood.sh`](scripts/chaos/mempool-flood.sh).
- [x] Validator fault simulation harness supporting active PID/Docker fault injection and observation in [`scripts/chaos/validator-failure-sim.sh`](scripts/chaos/validator-failure-sim.sh).
- [x] Protocol circuit breaker verification suite in [`scripts/chaos/circuit-breaker-test.sh`](scripts/chaos/circuit-breaker-test.sh).
- [x] Structured JSON reports generated under [`scripts/chaos/reports/`](scripts/chaos/reports/).
