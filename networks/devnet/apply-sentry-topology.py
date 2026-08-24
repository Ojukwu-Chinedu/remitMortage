#!/usr/bin/env python3
"""Rewrite p2p settings on top of a `pystarport init` output so validator
nodes only ever peer with their designated sentry, and each sentry hides its
validator's address from the rest of the mesh.

pystarport itself only knows how to wire one uniform full-mesh
persistent_peers string across every node (see its `init_devnet` /
`edit_tm_cfg`); it has no concept of per-role topology. Real node IDs are
also only known *after* `pystarport init` has generated each node's
node_key.json, so this cannot be expressed as static values inside
pystarport.json ahead of time - it has to run as a distinct pass, after
init and before start.

Usage:
    apply-sentry-topology.py <chain-data-dir> <binary-path> <base-port>

Where <chain-data-dir> is e.g. networks/devnet/data/arkdevnet_9000-1, matching
the "validators" node order in pystarport.json:
    node0 = sentry-0      node1 = validator-0
    node2 = sentry-1      node3 = validator-1
"""
import subprocess
import sys
from pathlib import Path

import tomlkit

NODE_ROLES = ["sentry-0", "validator-0", "sentry-1", "validator-1"]
SENTRY_VALIDATOR_PAIRS = [(0, 1), (2, 3)]  # (sentry_index, validator_index)


def node_id(binary, data_dir, i):
    home = data_dir / f"node{i}"
    result = subprocess.run(
        [str(binary), "comet", "show-node-id", "--home", str(home)],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def p2p_port(base_port, i):
    # Matches pystarport.ports.p2p_port(base_port) == base_port, and
    # process_config's base_port assignment of base_port + i * 10 per node.
    return base_port + i * 10


def peer_string(node_ids, base_port, i):
    # DevSkim: ignore DS162092 -- this is the local 4-node devnet's own p2p
    # topology, not production code; every node genuinely runs on 127.0.0.1
    # by design (see networks/devnet/README.md's "config-only on localhost"
    # note in GAPS.md - real sentry isolation needs actual separate hosts).
    return f"tcp://{node_ids[i]}@127.0.0.1:{p2p_port(base_port, i)}"


def patch_p2p(data_dir, i, fields):
    path = data_dir / f"node{i}" / "config" / "config.toml"
    doc = tomlkit.parse(path.read_text())
    for key, value in fields.items():
        doc["p2p"][key] = value
    path.write_text(tomlkit.dumps(doc))


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(1)

    data_dir = Path(sys.argv[1])
    binary = Path(sys.argv[2]).resolve()
    base_port = int(sys.argv[3])

    if not data_dir.is_dir():
        sys.exit(f"error: chain data dir not found: {data_dir}")
    if not binary.is_file():
        sys.exit(f"error: binary not found: {binary}")

    node_ids = {i: node_id(binary, data_dir, i) for i in range(len(NODE_ROLES))}
    peers = {i: peer_string(node_ids, base_port, i) for i in range(len(NODE_ROLES))}

    print("Applying sentry-node p2p topology:")
    for sentry_i, validator_i in SENTRY_VALIDATOR_PAIRS:
        other_sentry_i = next(s for s, _ in SENTRY_VALIDATOR_PAIRS if s != sentry_i)

        # Validator: talk ONLY to its own sentry, never discover any other
        # peer by any means. This is the actual isolation guarantee.
        patch_p2p(
            data_dir,
            validator_i,
            {
                "persistent_peers": peers[sentry_i],
                "pex": False,
                "addr_book_strict": False,
            },
        )

        # Sentry: talk to its validator and to the other sentry (the public
        # relay tier), but never let the validator's address leak out via
        # PEX gossip, and never let peer-limit churn drop the validator link.
        patch_p2p(
            data_dir,
            sentry_i,
            {
                "persistent_peers": ",".join(
                    [peers[validator_i], peers[other_sentry_i]]
                ),
                "pex": True,
                "private_peer_ids": node_ids[validator_i],
                "unconditional_peer_ids": node_ids[validator_i],
            },
        )

        print(
            f"  node{validator_i} ({NODE_ROLES[validator_i]}): "
            f"persistent_peers=[node{sentry_i}] pex=false"
        )
        print(
            f"  node{sentry_i} ({NODE_ROLES[sentry_i]}): "
            f"persistent_peers=[node{validator_i}, node{other_sentry_i}] "
            f"private_peer_ids=[node{validator_i}]"
        )


if __name__ == "__main__":
    main()
