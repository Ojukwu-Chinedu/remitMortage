# Gentx pipeline rehearsal fixtures

**Everything in this directory is fake.** `gentx/*.json` were generated
locally with throwaway `--keyring-backend test` keys that exist nowhere
else and were never used for anything but testing this pipeline. None of
these are real validator identities, real gentx submissions, or usable for
anything beyond exercising `collect-gentx.sh`.

| File | What it is | Expected result |
|---|---|---|
| `gentx/valid-0.json`, `gentx/valid-1.json` | Correctly signed, correctly funded `MsgCreateValidator` gentxs | ACCEPT |
| `gentx/bad-overclaim.json` | A valid gentx with `value.amount` edited *after* signing to claim more than the account's genesis balance | REJECT — insufficient self-delegation funds |
| `gentx/bad-tampered.json` | A valid gentx with 4 bytes of the base64 signature flipped | REJECT — signature verification failed |
| `base-genesis.json` | A throwaway chain (`arkmainnet_9001-1`) with `networks/mainnet/genesis-params.json`'s real param patch applied and 4 dummy funded accounts, no gentxs collected yet | Input to `collect-gentx.sh` |
| `transcript.log` | Captured stdout+exit code from actually running `collect-gentx.sh` and `hash-genesis.sh` against the fixtures above | Evidence, not a claim |

Reproduce yourself:

```bash
mkdir -p /tmp/rehearsal-out
./scripts/genesis/collect-gentx.sh \
  scripts/genesis/rehearsal/gentx \
  scripts/genesis/rehearsal/base-genesis.json \
  /tmp/rehearsal-out/genesis-template.json
echo "exit: $?"   # 1 - two of the four fixtures are deliberately bad

./scripts/genesis/hash-genesis.sh /tmp/rehearsal-out/genesis-template.json
```

`transcript.log` is exactly this output, captured verbatim - 2 accepted, 2
rejected with specific reasons, a compiled genesis containing only the
2 valid validators, and a non-zero exit code since some inputs failed.
