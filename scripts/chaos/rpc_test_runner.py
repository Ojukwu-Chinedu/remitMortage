#!/usr/bin/env python3
"""
ArkConstellation JSON-RPC Automated Test Suite
Track 3 (Security, Chaos & Smart Contracts) — Day 1 Deliverable

Automated end-to-end tests for:
1. JSON-RPC connectivity and chain parameters (eth_chainId, net_version, eth_blockNumber)
2. Account state queries (eth_getBalance, eth_getTransactionCount)
3. Smart contract deployment via raw signed transaction (eth_sendRawTransaction)
4. Transaction receipt verification (eth_getTransactionReceipt)
5. State-modifying function execution (eth_sendRawTransaction)
6. Read-only query execution (eth_call)
7. Log/event filtering (eth_getLogs)
8. Custom error and transaction revert validation
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request
import urllib.error
from typing import Any, Dict, Optional, Tuple

try:
    from eth_account import Account
    from eth_account.signers.local import LocalAccount
    import eth_utils
    from web3 import Web3
except ImportError:
    print("[-] Missing dependencies. Installing web3 and eth-account...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "web3", "eth-account"])
    from eth_account import Account
    from eth_account.signers.local import LocalAccount
    import eth_utils
    from web3 import Web3

# Colors for terminal output
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
BOLD = "\033[1m"
RESET = "\033[0m"


class JSONRPCClient:
    def __init__(self, rpc_url: str):
        self.rpc_url = rpc_url
        self.req_id = 1

    def call(self, method: str, params: Optional[list] = None) -> Any:
        if params is None:
            params = []
        payload = json.dumps({
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": self.req_id
        }).encode("utf-8")
        self.req_id += 1

        req = urllib.request.Request(
            self.rpc_url,
            data=payload,
            headers={"Content-Type": "application/json"}
        )

        try:
            with urllib.request.urlopen(req, timeout=15) as response:
                res_data = json.loads(response.read().decode("utf-8"))
                if "error" in res_data:
                    raise RuntimeError(f"RPC Error ({method}): {res_data['error']}")
                return res_data.get("result")
        except urllib.error.URLError as e:
            raise ConnectionError(f"Failed to connect to RPC at {self.rpc_url}: {e}")


def compile_test_contract(sol_path: str, solc_bin: str = "solc") -> Tuple[str, list]:
    """Compiles TestStorage.sol and returns (bytecode_hex, abi)."""
    cmd = [solc_bin, "--combined-json", "bin,abi", sol_path]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"solc compilation failed:\n{res.stderr}")
    
    data = json.loads(res.stdout)
    contract_key = next((k for k in data["contracts"] if "TestStorage" in k), None)
    if not contract_key:
        raise RuntimeError("TestStorage contract not found in compilation output")
    
    bin_hex = data["contracts"][contract_key]["bin"]
    abi = json.loads(data["contracts"][contract_key]["abi"])
    return "0x" + bin_hex, abi


def run_rpc_test_suite(
    rpc_url: str,
    expected_chain_id: int,
    private_key: str,
    solc_path: str
) -> Dict[str, Any]:
    print(f"\n{BOLD}{BLUE}============================================================{RESET}")
    print(f"{BOLD}{BLUE} Starting ArkConstellation JSON-RPC Automated Test Suite{RESET}")
    print(f"{BOLD}{BLUE}============================================================{RESET}")
    print(f"[*] Target RPC URL    : {rpc_url}")
    print(f"[*] Expected Chain ID : {expected_chain_id}")

    client = JSONRPCClient(rpc_url)
    account: LocalAccount = Account.from_key(private_key)
    print(f"[*] Tester Address    : {account.address}")

    results = []
    summary = {"total": 0, "passed": 0, "failed": 0, "skipped": 0, "tests": []}

    def record_test(name: str, passed: bool, details: str = "", skipped: bool = False):
        summary["total"] += 1
        if skipped:
            summary["skipped"] += 1
            status = f"{YELLOW}[SKIPPED]{RESET}"
        elif passed:
            summary["passed"] += 1
            status = f"{GREEN}[PASS]{RESET}"
        else:
            summary["failed"] += 1
            status = f"{RED}[FAIL]{RESET}"
        
        print(f"  {status} {name}")
        if details:
            print(f"         {details}")
        summary["tests"].append({
            "name": name,
            "passed": passed,
            "skipped": skipped,
            "details": details
        })

    # Test 1: Node Connectivity & Client Version
    try:
        client_version = client.call("web3_clientVersion")
        record_test("1. web3_clientVersion Query", True, f"Version: {client_version}")
    except Exception as e:
        record_test("1. web3_clientVersion Query", False, str(e))

    # Test 2: Chain ID Validation
    try:
        chain_id_hex = client.call("eth_chainId")
        actual_chain_id = int(chain_id_hex, 16)
        match = (actual_chain_id == expected_chain_id)
        record_test(
            "2. eth_chainId Verification",
            match,
            f"Expected: {expected_chain_id}, Got: {actual_chain_id} ({chain_id_hex})"
        )
    except Exception as e:
        record_test("2. eth_chainId Verification", False, str(e))

    # Test 3: Block Number & Gas Price
    try:
        block_num_hex = client.call("eth_blockNumber")
        gas_price_hex = client.call("eth_gasPrice")
        block_num = int(block_num_hex, 16)
        gas_price = int(gas_price_hex, 16)
        record_test(
            "3. eth_blockNumber & eth_gasPrice Queries",
            block_num >= 0,
            f"Block Height: {block_num}, Gas Price: {gas_price} wei ({gas_price_hex})"
        )
    except Exception as e:
        record_test("3. eth_blockNumber & eth_gasPrice Queries", False, str(e))

    # Test 4: Account Balance & Nonce
    nonce = 0
    balance = 0
    try:
        balance_hex = client.call("eth_getBalance", [account.address, "latest"])
        nonce_hex = client.call("eth_getTransactionCount", [account.address, "latest"])
        balance = int(balance_hex, 16)
        nonce = int(nonce_hex, 16)
        record_test(
            "4. Account Balance & Nonce Retrieval",
            True,
            f"Balance: {balance} esp ({balance / 10**18:.4f} KASH), Nonce: {nonce}"
        )
    except Exception as e:
        record_test("4. Account Balance & Nonce Retrieval", False, str(e))

    # Compile Test Storage Contract
    script_dir = os.path.dirname(os.path.abspath(__file__))
    sol_path = os.path.join(script_dir, "contracts", "TestStorage.sol")
    bytecode = ""
    abi = []
    try:
        bytecode, abi = compile_test_contract(sol_path, solc_path)
        record_test("5. TestStorage.sol Contract Compilation", True, f"Bytecode Size: {len(bytecode)//2} bytes")
    except Exception as e:
        record_test("5. TestStorage.sol Contract Compilation", False, str(e))

    if balance == 0:
        print(f"\n{YELLOW}[!] Warning: Tester account {account.address} has 0 balance.{RESET}")
        print(f"{YELLOW}[!] Contract deployment and state modification tests require funded account.{RESET}")
        print(f"{YELLOW}[!] Simulating / verifying offline encoding for deployment and function calls.{RESET}")

        # Verification of Offline Raw Transaction Construction & Signing
        try:
            w3 = Web3()
            contract = w3.eth.contract(abi=abi, bytecode=bytecode)
            deploy_data = contract.constructor(42).build_transaction({
                "from": account.address,
                "nonce": nonce,
                "gas": 1_000_000,
                "gasPrice": 10**9,
                "chainId": expected_chain_id
            })["data"]
            signed_tx = account.sign_transaction({
                "nonce": nonce,
                "gas": 1_000_000,
                "gasPrice": 10**9,
                "chainId": expected_chain_id,
                "data": deploy_data,
                "value": 0
            })
            record_test(
                "6. EIP-155 Raw Contract Deployment Signing Verification",
                len(signed_tx.raw_transaction) > 0,
                f"Generated Signed Raw Tx: {signed_tx.raw_transaction.hex()[:40]}... (Len: {len(signed_tx.raw_transaction)} bytes)"
            )
        except Exception as e:
            record_test("6. EIP-155 Raw Contract Deployment Signing Verification", False, str(e))

        record_test("7. Contract Execution (setValue)", True, "Skipped live broadcast (insufficient balance for gas)", skipped=True)
        record_test("8. State Read (eth_call getValue)", True, "Skipped live broadcast (insufficient balance for gas)", skipped=True)
        record_test("9. Event Filtering (eth_getLogs)", True, "Skipped live broadcast (insufficient balance for gas)", skipped=True)
        record_test("10. Revert Verification (testRevert)", True, "Skipped live broadcast (insufficient balance for gas)", skipped=True)

    else:
        # Live Contract Deployment
        deployed_contract_addr = None
        try:
            w3 = Web3()
            contract = w3.eth.contract(abi=abi, bytecode=bytecode)
            constructor_tx = contract.constructor(42).build_transaction({
                "from": account.address,
                "nonce": nonce,
                "gas": 1_500_000,
                "gasPrice": max(int(client.call("eth_gasPrice"), 16), 10**9),
                "chainId": expected_chain_id
            })
            signed_deploy = account.sign_transaction(constructor_tx)
            tx_hash = client.call("eth_sendRawTransaction", [signed_deploy.raw_transaction.hex()])
            print(f"[*] Deployment Tx Broadcasted: {tx_hash}")

            # Poll for receipt
            receipt = None
            for _ in range(20):
                time.sleep(1)
                receipt = client.call("eth_getTransactionReceipt", [tx_hash])
                if receipt:
                    break

            if receipt and receipt.get("status") == "0x1":
                deployed_contract_addr = receipt["contractAddress"]
                record_test(
                    "6. Contract Deployment via eth_sendRawTransaction",
                    True,
                    f"Contract Deployed At: {deployed_contract_addr}, Block: {int(receipt['blockNumber'], 16)}"
                )
            else:
                record_test("6. Contract Deployment via eth_sendRawTransaction", False, f"Receipt: {receipt}")
        except Exception as e:
            record_test("6. Contract Deployment via eth_sendRawTransaction", False, str(e))

        if deployed_contract_addr:
            nonce += 1
            # Test 7: Contract State Mutation (setValue)
            try:
                set_val_data = "0x55241077" + eth_utils.encode_hex(eth_utils.to_bytes(primitive=1337)).rjust(64, '0')
                tx_set = {
                    "to": deployed_contract_addr,
                    "from": account.address,
                    "nonce": nonce,
                    "gas": 200_000,
                    "gasPrice": max(int(client.call("eth_gasPrice"), 16), 10**9),
                    "chainId": expected_chain_id,
                    "data": set_val_data,
                    "value": 0
                }
                signed_set = account.sign_transaction(tx_set)
                set_tx_hash = client.call("eth_sendRawTransaction", [signed_set.raw_transaction.hex()])
                print(f"[*] State Modification Tx Broadcasted: {set_tx_hash}")

                set_receipt = None
                for _ in range(20):
                    time.sleep(1)
                    set_receipt = client.call("eth_getTransactionReceipt", [set_tx_hash])
                    if set_receipt:
                        break

                record_test(
                    "7. Contract State Modification (setValue(1337))",
                    set_receipt and set_receipt.get("status") == "0x1",
                    f"Tx Hash: {set_tx_hash}, Gas Used: {int(set_receipt['gasUsed'], 16) if set_receipt else 'N/A'}"
                )
            except Exception as e:
                record_test("7. Contract State Modification (setValue(1337))", False, str(e))

            # Test 8: Contract Read Query (eth_call getValue)
            try:
                get_val_data = "0x20965255"
                call_res = client.call("eth_call", [{"to": deployed_contract_addr, "data": get_val_data}, "latest"])
                val = int(call_res, 16)
                record_test(
                    "8. Read Query via eth_call (getValue())",
                    val == 1337,
                    f"Expected: 1337, Returned: {val} ({call_res})"
                )
            except Exception as e:
                record_test("8. Read Query via eth_call (getValue())", False, str(e))

            # Test 9: Event Log Retrieval (eth_getLogs)
            try:
                logs = client.call("eth_getLogs", [{
                    "fromBlock": "0x1",
                    "toBlock": "latest",
                    "address": deployed_contract_addr
                }])
                record_test(
                    "9. Event Log Filtering (eth_getLogs)",
                    len(logs) >= 2,  # ContractInitialized + ValueSet
                    f"Retrieved {len(logs)} event log(s) for contract {deployed_contract_addr}"
                )
            except Exception as e:
                record_test("9. Event Log Filtering (eth_getLogs)", False, str(e))

            # Test 10: Revert Handling (testRevert(0))
            try:
                revert_call_data = "0x" + "c6e8e815" + "0" * 64
                client.call("eth_call", [{"to": deployed_contract_addr, "data": revert_call_data}, "latest"])
                record_test("10. Revert Verification (testRevert(0))", False, "Expected revert but call succeeded")
            except Exception as e:
                record_test("10. Revert Verification (testRevert(0))", True, f"Revert successfully caught: {e}")

    # Output Summary
    print(f"\n{BOLD}{BLUE}============================================================{RESET}")
    print(f"{BOLD} Test Suite Summary{RESET}")
    print(f" Total Tests : {summary['total']}")
    print(f" Passed      : {GREEN}{summary['passed']}{RESET}")
    print(f" Failed      : {RED}{summary['failed']}{RESET}")
    print(f" Skipped     : {YELLOW}{summary['skipped']}{RESET}")
    print(f"{BOLD}{BLUE}============================================================{RESET}")

    report_path = os.path.join(script_dir, "reports", "rpc-test-results.json")
    with open(report_path, "w") as f:
        json.dump(summary, f, indent=2)
    print(f"[*] Detailed test report written to: {report_path}\n")

    return summary


def main():
    parser = argparse.ArgumentParser(description="ArkConstellation JSON-RPC Automated Test Suite")
    parser.add_argument("--rpc", default=os.getenv("EVM_RPC", "http://127.0.0.1:8545"), help="JSON-RPC Endpoint URL")
    parser.add_argument("--chain-id", type=int, default=int(os.getenv("CHAIN_ID", "11199")), help="EVM Chain ID")
    parser.add_argument("--private-key", default=os.getenv("PRIVATE_KEY", "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"), help="Test account private key")
    parser.add_argument("--solc", default=os.path.expanduser("~/.solc-bin/solc"), help="Path to solc compiler binary")
    args = parser.parse_args()

    summary = run_rpc_test_suite(args.rpc, args.chain_id, args.private_key, args.solc)
    if summary["failed"] > 0:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
