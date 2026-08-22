#!/usr/bin/env python3
"""Re-encode a bech32 address under a different human-readable prefix,
e.g. `mantravaloper1...` -> `mantra1...`. Same underlying data, different
HRP - this is exactly how a validator operator address and its underlying
account address relate in the Cosmos SDK.

Self-contained (no `bech32` pip package dependency) since this runs inside
collect-gentx.sh, which needs to work reliably with only what's already on
a bare system (python3 + jq), not whatever happens to be pip-installed.
Standard BIP-173 reference algorithm, unmodified.

Usage: bech32_reencode.py <address> <new-hrp>
"""
import sys

CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"


def bech32_polymod(values):
    generator = [0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3]
    chk = 1
    for v in values:
        top = chk >> 25
        chk = (chk & 0x1FFFFFF) << 5 ^ v
        for i in range(5):
            chk ^= generator[i] if ((top >> i) & 1) else 0
    return chk


def bech32_hrp_expand(hrp):
    return [ord(x) >> 5 for x in hrp] + [0] + [ord(x) & 31 for x in hrp]


def bech32_create_checksum(hrp, data):
    values = bech32_hrp_expand(hrp) + data
    polymod = bech32_polymod(values + [0, 0, 0, 0, 0, 0]) ^ 1
    return [(polymod >> 5 * (5 - i)) & 31 for i in range(6)]


def bech32_decode(bech):
    if any(ord(c) < 33 or ord(c) > 126 for c in bech):
        raise ValueError("invalid character in bech32 string")
    if bech.lower() != bech and bech.upper() != bech:
        raise ValueError("mixed case bech32 string")
    bech = bech.lower()
    pos = bech.rfind("1")
    if pos < 1 or pos + 7 > len(bech):
        raise ValueError("invalid bech32 separator position")
    hrp = bech[:pos]
    data_part = bech[pos + 1 :]
    data = []
    for c in data_part:
        if c not in CHARSET:
            raise ValueError(f"invalid bech32 character: {c!r}")
        data.append(CHARSET.index(c))
    values = bech32_hrp_expand(hrp) + data
    if bech32_polymod(values) != 1:
        raise ValueError("invalid bech32 checksum")
    return hrp, data[:-6]


def bech32_encode(hrp, data):
    combined = data + bech32_create_checksum(hrp, data)
    return hrp + "1" + "".join(CHARSET[d] for d in combined)


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: bech32_reencode.py <address> <new-hrp>")
    address, new_hrp = sys.argv[1], sys.argv[2]
    _, data = bech32_decode(address)
    print(bech32_encode(new_hrp, data))


if __name__ == "__main__":
    main()
