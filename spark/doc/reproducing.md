# Reproducing the results

There are two paths. The **FSF path** needs only free tools, and
reproduces everything CI checks: the proofs, the FFI check against the
Cryptol, coverage, and the performance harness. The
**SAW path** also needs GNAT Pro 27's LLVM back end, which is not freely
available; it reproduces the SAW proofs recorded in `saw/results.txt`.

Every version below is pinned in
[`scripts/toolchain-pins.env`](../scripts/toolchain-pins.env). CI's setup
action and the bootstrap script both read that file. Back to the
[README](../README.md).

## The FSF path

### Tools

| tool | version | needed for |
|---|---|---|
| Alire (`alr`) | 2.1.1 | everything: it fetches the compiler and the provers |
| gnat_native, gprbuild | 16.1.0, 26.0.1 | building |
| gnatprove | 16.1.0 | proof |
| gnatdoc_bin | 26.0.0 | the documentation gate |
| Cryptol, built with FFI support, and z3 | 3.6.0 | the FFI check |
| gnatcov | 26.2.1 | coverage |

Where to get them:

- **Alire 2.1.1**: its [release
  page](https://github.com/alire-project/alire/releases/tag/v2.1.1). The
  bootstrap pins `alr-2.1.1-bin-x86_64-linux.zip`; the page has builds
  for other platforms too.
- **Cryptol 3.6.0**: its [release
  page](https://github.com/GaloisInc/cryptol/releases/tag/3.6.0). CI and
  the bootstrap pin `cryptol-3.6.0-ubuntu-24.04-X64-with-solvers.tar.gz`.
- The rest come through `alr`, as below.

The sha256 of each pinned download is in `toolchain-pins.env`.

gnat_native 16.1.0 is the compiler that matches gnatprove 16.1.0: both
have GNAT 16's front end, so they read the sources alike. The crate
depends on no other crate. gprbuild 26.0.1 is the version Alire installs,
but `gprbuild --version` prints `GPRBUILD 26.0.0`.

Cryptol must say `FFI enabled` in `cryptol --version`. Galois's release
builds for x86_64 Linux and macOS do. There is no release for aarch64
Linux; [bootstrap.md](bootstrap.md) shows how to build one from source.
Use the release "with solvers": Cryptol's type checker needs z3.

### Steps

From a checkout of the repository:

```console
$ alr -n toolchain --select gnat_native=16.1.0 gprbuild=26.0.1
$ alr -n install gnatprove=16.1.0
$ export PATH="$HOME/.alire/bin:$PATH"
$ cd spark
$ alr -n build
```

`alr -n build` also generates `config/foundation_spark_config.gpr`, which
the project needs; run it once in a fresh checkout before anything else.

**Prove.** CI's proof gate is `scripts/check-proof.sh`, run under CI's
allowance:

```console
$ FOUNDATION_SPARK_PROOF_ALLOWANCE=ci scripts/check-proof.sh
$ scripts/board.py
```

`check-proof.sh` calls gnatprove through `scripts/prove.sh` at each unit's
committed level, fails on any unproved check, and checks that every unit it
expected was analyzed. `PROVE_JOBS` sets gnatprove's `-j` (default: every
core). One generated unit is too slow for the gate and is proved on
demand with `scripts/prove-slow.sh`; the gate checks that its recorded
proof is still current. `board.py` counts the results. Details:
[proving.md](proving.md).

The gate runs on arm64 Linux in CI. It passes on x86_64 Linux too: on an
x86_64 instance with 8 vCPUs, a cold run at `383bce7` under CI's
allowance (`-j8`) proved all 4085 checks in 13:59 wall-clock
([bootstrap.md](bootstrap.md#bootstrapping-the-x86_64-instance)).

**Check against the Cryptol.**

```console
$ scripts/check-ffi.sh                  # every property
$ scripts/check-ffi.sh prop_xTimes      # only these
```

It builds the crate as a shared library with ghost code enabled, and runs
each property of `cryptol/properties.txt` in its own `cryptol -b`. It
needs python3; macOS's bash 3.2 is enough. On macOS it handles
Galois's signed Cryptol binary itself. Details: [ffi.md](ffi.md).

**Coverage** (Linux):

```console
$ alr -n install gnatcov=26.2.1
$ scripts/check-coverage.sh
```

Details: [coverage.md](coverage.md).

**Performance** (optional):

```console
$ alr -n exec -- scripts/perf-aes.sh           # needs cargo, for NSA's Rust AES
```

Details: [performance.md](performance.md).

**The documentation gates:**

```console
$ scripts/check-doc-placement.sh       # no toolchain needed
$ alr -n install gnatdoc_bin=26.0.0
$ scripts/check-docs.sh
$ scripts/check-trust-surface.sh
```

### One command, on x86_64 Linux

On a bare Ubuntu 24.04 x86_64 machine, `scripts/bootstrap-x86_64.sh` does
all of the above that CI does (tools, clone, build, proof, FFI check) in
one command, and can be rerun at any time:

```console
$ curl -fsSL https://raw.githubusercontent.com/manthonyaiello/Foundation/main/spark/scripts/bootstrap-x86_64.sh | bash
```

Its phases, its variables and what it needs root for are in
[bootstrap.md](bootstrap.md#bootstrapping-the-x86_64-instance).

### What CI runs

| workflow | runner | what |
|---|---|---|
| `spark-ci.yml` | arm64 Linux | trust surface, documentation, the proof gate (`spark-prove.yml`) |
| `spark-ci.yml`, FFI job | x86_64 Linux | `check-ffi.sh` (Cryptol has no arm64 Linux release) |
| `spark-coverage.yml` | x86_64 Linux | `check-coverage.sh` |
| `spark-prove-slow.yml` | arm64 Linux, by hand | the slow unit's proof |
| `spark-bootstrap-x86_64.yml` | x86_64 Linux | the bootstrap script, on a bare runner and in a bare container |

## The SAW path (GNAT Pro)

SAW proves the LLVM bitcode of the crate equal to NSA's Cryptol. The
bitcode must come from **GNAT Pro 27's LLVM back end** (`llvm-gcc`). It is
used for nothing else: the crate's own toolchain stays FSF GNAT 16.1.
Because few people can rerun it, each run records its full provenance in
`saw/results.txt`, which is committed. What it proves:
[saw.md](saw.md).

### Tools

| tool | version | note |
|---|---|---|
| GNAT Pro's LLVM back end (`llvm-gcc`, `llvm-nm`) | 27 | named by `GNAT_LLVM_DIR`; never downloaded by any script |
| `llvm-link` | 21.1.8 | from LLVM's own release (GNAT Pro ships none); must be the LLVM version of `llvm-gcc`; named by `LLVM_LINK_DIR` |
| SAW | 1.6 | the release "with solvers" |
| Cryptol, z3 | 3.6.0 | on `PATH` |

The recorded runs used an x86_64 Linux instance. On x86_64 Linux the
bootstrap installs SAW, and, when `GNAT_LLVM_DIR` is set, checks it and
fetches the pinned `llvm-link` (it extracts `bin/llvm-link` alone from
LLVM's 2 GB release tarball, after checking its sha256):

```console
$ GNAT_LLVM_DIR=<the GNAT Pro LLVM install> scripts/bootstrap-x86_64.sh
```

### Steps

```console
$ GNAT_LLVM_DIR=<dir> LLVM_LINK_DIR=<dir> scripts/check-saw.sh   # writes saw/results.txt
$ scripts/check-saw.sh --print                                     # writes nothing
$ SAW_LONG=1 scripts/check-saw.sh                                  # also the long proofs; writes saw/results-long.txt
$ SAW_LAYERS=impl scripts/check-saw.sh --print                     # one layer only (impl or spec)
```

`saw`, `cryptol` and `z3` must be on `PATH` (the bootstrap's `env.sh`
puts them there). Writing the record needs a clean tree, since the record
names `HEAD`. Each `saw` run is capped at 10 GB of memory through
`systemd-run --user` where that works (`SAW_MEMORY_MAX` changes it).

The recorded default run took 2749 s, and the `SAW_LONG=1` run 6257 s
(the `wall-clock` lines of `saw/results.txt` and `saw/results-long.txt`,
both at commit `82b10e6`, on an x86_64 Linux instance with 8 CPUs).

`scripts/board.py` reports a SAW record **stale** when any input it
hashed (a source, a Cryptol file, a SAW script) has changed since. Only a
new `check-saw.sh` run clears it.
