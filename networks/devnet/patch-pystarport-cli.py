#!/usr/bin/env python3
"""Two idempotent patches to installed pystarport 0.2.5 for this repo's
actual binary behavior. Both fail loudly if pystarport's source no longer
matches what they expect to replace, rather than silently no-op'ing.

1. cosmoscli.py - two independent CLI-shape mismatches between
   pystarport 0.2.5 (latest on PyPI) and this repo's binary:
   a. Cosmos SDK v0.50+ nests `add-genesis-account`/`gentx`/
      `collect-gentxs`/`validate-genesis` under a `genesis` subcommand;
      pystarport still calls them as root-level commands, which fails
      immediately with "unknown command \"add-genesis-account\" for
      \"mantrachaind\"".
   b. This binary's CLI has renamed `tendermint show-node-id` to
      `comet show-node-id` (following upstream CometBFT's own rename);
      pystarport still calls the old `tendermint` subcommand, which
      fails with "unknown command \"tendermint\" for \"mantrachaind\"".

2. utils.py - `interact()` sets `stderr=subprocess.STDOUT` by default,
   merging both streams before returning stdout to the caller. This
   repo's compiled binary (this specific Go toolchain + the `sonic` JSON
   library it pulls in transitively) writes a one-line environment
   compatibility warning to stderr on every invocation. Merged into
   stdout, that warning corrupts every `--output json` response pystarport
   tries to `json.loads()`, e.g. `keys add` during `pystarport init`
   failing with "JSONDecodeError: Expecting value: line 1 column 1".
   Patched so stdout/stderr are captured separately: callers still get
   clean stdout on success, and stderr is folded into the error message
   only when the command actually fails (preserving pystarport's own
   debuggability on real failures).
"""
import sys
from pathlib import Path

FILE_PATCHES = {
    "cosmoscli.py": [
        ('return self.raw("validate-genesis", *args, home=self.data_dir)',
         'return self.raw("genesis", "validate-genesis", *args, home=self.data_dir)'),
        ('"add-genesis-account",\n            addr,',
         '"genesis",\n            "add-genesis-account",\n            addr,'),
        ('return self.raw(\n            "gentx",\n            name,',
         'return self.raw(\n            "genesis",\n            "gentx",\n            name,'),
        ('return self.raw("collect-gentxs", gentx_dir, home=self.data_dir)',
         'return self.raw("genesis", "collect-gentxs", gentx_dir, home=self.data_dir)'),
        ('output = self.raw("tendermint", "show-node-id", home=self.data_dir)',
         'output = self.raw("comet", "show-node-id", home=self.data_dir)'),
    ],
    "utils.py": [
        (
            'def interact(cmd, ignore_error=False, input=None, **kwargs):\n'
            '    kwargs.setdefault("stderr", subprocess.STDOUT)\n'
            '    proc = subprocess.Popen(\n'
            '        cmd,\n'
            '        stdin=subprocess.PIPE,\n'
            '        stdout=subprocess.PIPE,\n'
            '        shell=True,\n'
            '        **kwargs,\n'
            '    )\n'
            '    # begin = time.perf_counter()\n'
            '    (stdout, _) = proc.communicate(input=input)\n'
            '    # print(\'[%.02f] %s\' % (time.perf_counter() - begin, cmd))\n'
            '    if not ignore_error:\n'
            '        assert proc.returncode == 0, f\'{stdout.decode("utf-8")} ({cmd})\'\n'
            '    return stdout',

            'def interact(cmd, ignore_error=False, input=None, **kwargs):\n'
            '    kwargs.setdefault("stderr", subprocess.PIPE)\n'
            '    proc = subprocess.Popen(\n'
            '        cmd,\n'
            '        stdin=subprocess.PIPE,\n'
            '        stdout=subprocess.PIPE,\n'
            '        shell=True,\n'
            '        **kwargs,\n'
            '    )\n'
            '    # begin = time.perf_counter()\n'
            '    (stdout, stderr) = proc.communicate(input=input)\n'
            '    # print(\'[%.02f] %s\' % (time.perf_counter() - begin, cmd))\n'
            '    if not ignore_error:\n'
            '        assert proc.returncode == 0, (\n'
            '            f\'{stdout.decode("utf-8")}{stderr.decode("utf-8")} ({cmd})\'\n'
            '        )\n'
            '    return stdout',
        ),
    ],
}


def patch_file(target, patches):
    text = target.read_text()

    # Each (old, new) pair is checked independently, not all-or-nothing:
    # a file can have some patches already applied from a previous run
    # and others still pending (e.g. this script gained a new patch entry
    # after the venv was first set up).
    to_apply = []
    unexpected = []
    for old, new in patches:
        if new in text:
            continue  # already applied
        if old in text:
            to_apply.append((old, new))
        else:
            unexpected.append(old)

    if unexpected:
        sys.exit(
            f"error: {target}'s source no longer matches the text this "
            "patch expects to replace - it may have been updated upstream. "
            "Re-check whether the fix is still needed, then update "
            "FILE_PATCHES in this script.\n"
            f"Unmatched patterns:\n" + "\n---\n".join(unexpected)
        )

    if not to_apply:
        print(f"{target.name} already patched, nothing to do.")
        return

    for old, new in to_apply:
        text = text.replace(old, new, 1)
    target.write_text(text)
    print(f"Patched {target} ({len(to_apply)} change(s)).")


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: patch-pystarport-cli.py <path-to-venv>")

    venv = Path(sys.argv[1])
    pkg_matches = list(venv.glob("lib/python*/site-packages/pystarport"))
    if len(pkg_matches) != 1:
        sys.exit(
            f"error: expected exactly one pystarport package dir under {venv}, "
            f"found {pkg_matches}"
        )
    pkg_dir = pkg_matches[0]

    for filename, patches in FILE_PATCHES.items():
        target = pkg_dir / filename
        if not target.is_file():
            sys.exit(f"error: expected {target} to exist")
        patch_file(target, patches)


if __name__ == "__main__":
    main()
