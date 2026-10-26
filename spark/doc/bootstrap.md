# Bootstrapping the toolchain

Installing Cryptol with FFI support (including building it from source
where there is no release), and the one-command bootstrap of an x86_64
Linux machine. The short version is in [reproducing.md](reproducing.md).
Back to the [README](../README.md).

## Cryptol

The FFI checks (`spark/cryptol/`, M0.3 onward) need Cryptol 3.6.0 built
with FFI support (`cryptol --version` prints `FFI enabled`). SAW is
installed only on the x86_64 Linux instance, by its bootstrap
("Bootstrapping the x86_64 instance", below).

### `CRYPTOLPATH`

The NSA modules are named from the repository root
(`algorithms::AES::Main`, `shared::...`), so `CRYPTOLPATH` must hold the
repository root. `scripts/check-ffi.sh` sets it to the repository root and
`spark/cryptol`, so a property module imports `algorithms::AES::GF28` by
its NSA name.

```console
$ export CRYPTOLPATH=/path/to/Foundation
$ cryptol -b script.icry
```

### aarch64 Linux (a container, built from source)

Cryptol 3.6.0 ships no aarch64 Linux binary. The release has macOS
ARM64/x86_64 and x86_64 Linux/Windows builds only. No packaged route was
credible:
* Ubuntu 24.04's `cryptol` package is 3.0.0.
* The Docker Hub `galoisinc/cryptol` images are amd64 only, and the
  container has no docker, podman or nix.

So it was built from the `3.6.0` tag, with GHC 9.8.4 and cabal 3.14.1.0
(the versions upstream's CI uses for its release builds), against the
release's own freeze file `cabal.GHC-9.8.4.config`. That file sets
`cryptol +ffi` and `libffi +ghc-bundled-libffi`. Nothing needed sudo.

The container has no system C toolchain (no `/usr/bin/gcc`, `cc`, `ld` or
`ar`), so GHC and cabal used the gcc 16.1.0 and binutils from Alire's
`gnat_native` toolchain. It also has no `-dev` packages, so the headers,
the link-time `.so` symlinks and `pkgconf` came from Ubuntu's `.deb`s,
unpacked without installing them. The resulting `cryptol` links only
against system libraries (`libm`, `libtinfo`, `libz`, `libgmp`, `libc`).

```console
# Headers and pkgconf from Ubuntu debs, unpacked into ~/.local/sysroot.
$ mkdir -p ~/build/apt/state/lists/partial ~/build/apt/cache/archives/partial ~/build/debs
$ apt-get -o Dir::State=$HOME/build/apt/state -o Dir::Cache=$HOME/build/apt/cache \
    -o Debug::NoLocking=1 -o APT::Sandbox::User=$(whoami) update
$ cd ~/build/debs
$ apt-get -o Dir::State=$HOME/build/apt/state -o Dir::Cache=$HOME/build/apt/cache \
    download libffi-dev libgmp-dev zlib1g-dev libncurses-dev \
    pkgconf pkgconf-bin libpkgconf3 z3 libz3-4
$ for d in ~/build/debs/*.deb; do dpkg-deb -x $d ~/.local/sysroot; done
# Then: point each dangling lib*.so symlink in
# ~/.local/sysroot/usr/lib/aarch64-linux-gnu at the runtime library in
# /usr/lib/aarch64-linux-gnu, and rewrite the prefix/libdir/includedir
# of the .pc files there to ~/.local/sysroot. ~/.local/bin/pkg-config
# and ~/.local/bin/z3 are two-line wrappers that set LD_LIBRARY_PATH (and,
# for pkg-config, PKG_CONFIG_LIBDIR) to the sysroot before exec'ing it.

# GHC 9.8.4 and cabal 3.14.1.0 through ghcup, in ~/.ghcup.
$ mkdir -p ~/.ghcup/bin
$ curl -sSfL -o ~/.ghcup/bin/ghcup https://downloads.haskell.org/~ghcup/aarch64-linux-ghcup
$ chmod +x ~/.ghcup/bin/ghcup
$ S=$HOME/.local/sysroot
$ export PATH=$HOME/.ghcup/bin:$HOME/.local/bin:<gnat_native 16.1.0's bin directory>:$PATH
$ export LIBRARY_PATH=$S/usr/lib/aarch64-linux-gnu
$ export C_INCLUDE_PATH=$S/usr/include/aarch64-linux-gnu:$S/usr/include
$ CC=gcc ghcup install ghc 9.8.4 --set
$ ghcup install cabal 3.14.1.0 --set

# Cryptol 3.6.0, installed as ~/.local/bin/cryptol.
$ git clone --depth 1 --branch 3.6.0 --recurse-submodules --shallow-submodules \
    https://github.com/GaloisInc/cryptol.git ~/build/cryptol-3.6.0
$ cd ~/build/cryptol-3.6.0
$ cp cabal.GHC-9.8.4.config cabal.project.freeze
$ cabal update
$ cabal build -j4 exe:cryptol
$ install -m755 "$(cabal list-bin exe:cryptol)" ~/.local/bin/cryptol
```

The first `cabal build` stopped after compiling the `cryptol` library.
cabal's `act-as-setup configure` for the `cryptol-repl-internal`
sublibrary never reaped a `pkgconf` child that had already exited, and
hung there. Killing it and rerunning the same command finished the build
in 15 s from the store. Before the hang, the build had run for about 11
minutes at `-j4`, on a container shared with two other jobs.

```console
$ cryptol --version
Cryptol 3.6.0
Git commit 61dd17b0c45ddf8c5c1e952afd5e789c4dc4ec4b
    branch HEAD
FFI enabled
```

An SMT solver is optional, since `:check` and `:exhaust` do not use one.
Ubuntu's z3 4.8.12 is unpacked in the sysroot behind the `~/.local/bin/z3`
wrapper.

On Linux, Cryptol looks for a module's foreign implementations in
`<Module>.so` beside the `.cry` file (`<Module>.dylib` on macOS).

### CI

CI (M0.3) uses the `cryptol-3.6.0-ubuntu-24.04-X64-with-solvers` release
tarball on an x86_64 runner: the release without solvers refuses to start
without z3. No arm64 Linux release exists.

## Bootstrapping the x86_64 instance

`scripts/bootstrap-x86_64.sh` takes an x86_64 Linux machine from a bare
Ubuntu 24.04 to a green `check-ffi.sh` in one command. The campaign used
it on short-lived x86_64 Linux instances, which it brought up for SAW
(E4) and the x86_64 measurements:

```console
$ curl -fsSL https://raw.githubusercontent.com/manthonyaiello/Foundation/main/spark/scripts/bootstrap-x86_64.sh | bash
```

Then, in each new shell, source the `env.sh` the script writes in its tools
directory (`FOUNDATION_TOOLS`; the script prints the path, and the
`export PATH=...` line). gnatprove runs with `-j$(nproc)` (`PROVE_JOBS`
defaults to `nproc`); set `PROVE_JOBS` lower on a shared machine. On a
machine that will not live long, push each commit as it is made.

`scripts/bootstrap-x86_64.sh` (M0.5, #6) is idempotent: each phase skips
what is in place, so rerun it after anything goes wrong.

**Present or fetched** (#100). Each tool is used where it is when it is
present and its version matches its pin, and fetched (the pinned
release, sha256 checked) only when it is not. Present means, in this
order: in the directory its environment variable names (`LLVM_LINK_DIR`,
for `llvm-link`), on `PATH`, or where an earlier run fetched it. Cryptol
must also have FFI support and a `z3` beside it or on `PATH`. The script
says which, per tool, as it goes ("present and matching the pin" or
"fetched") and in a table at the end, and a run with every tool present
fetches nothing. Only the directories of tools `PATH` did not already
find are added to it, and to `env.sh`.

Its phases, each timed at the end of the run (the versions are the pins;
"fetched" says what is fetched when the tool is not present):

| phase | what |
|---|---|
| `prereqs` | curl, git, python3, CA certificates, `libc6-dev`; missing ones are apt-installed |
| `clone` | clones the fork to `~/Foundation`, or fetches it and fast-forwards a clean checkout |
| `alire` | alr 2.1.1, gnat_native 16.1.0 and gprbuild 26.0.1, gnatprove 16.1.0, gnatdoc_bin 26.0.0. Fetched: alr's release zip; the toolchain with `alr toolchain --select`; gnatprove and gnatdoc_bin with `alr install` |
| `cryptol` | Cryptol 3.6.0. Fetched: the `ubuntu-24.04-X64-with-solvers` release |
| `saw` | SAW 1.6. Fetched: the `ubuntu-24.04-X64-with-solvers` release |
| `gnat-llvm` | checks the GNAT Pro LLVM install that `GNAT_LLVM_DIR` names (nothing of it is ever downloaded), and `llvm-link` 21.1.8. Fetched: LLVM's own 21.1.8 release (2 GB tarball, sha256 checked, `bin/llvm-link` alone extracted). Writes `GNAT_LLVM_DIR` and `LLVM_LINK_DIR` to `env.sh`; skipped, with a note, when `GNAT_LLVM_DIR` is unset ("SAW") |
| `build` | `alr -n build` |
| `proof` | `scripts/check-proof.sh`, slow units skipped as in CI ([proving.md, "Slow proofs"](proving.md#slow-proofs)), under CI's allowance (`FOUNDATION_SPARK_PROOF_ALLOWANCE=ci` unless set); retried once on failure, and then reported as "ok on retry"; skipped with `--no-proof` |
| `ffi` | `scripts/check-ffi.sh` |

Every version and release sha256 comes from `scripts/toolchain-pins.env`,
which CI's `setup-alire-spark` action reads too, so the instance and CI
cannot drift apart. Fetched tools go to the tools directory
(`FOUNDATION_TOOLS`, default in the script's header), Alire's state to `~/.alire` and
`~/.local/share/alire` as in CI. The
header of the script lists its other variables (`FOUNDATION_REPO`,
`FOUNDATION_REF`, `FOUNDATION_SPARK_PROOF_ALLOWANCE`, ...).

**Root** is needed only for packages the image lacks: in `prereqs`, and
for a fetched tool (`xz-utils` to unpack LLVM's tarball, and the shared
libraries of a fetched Cryptol, SAW or `llvm-link`, checked with `ldd`
after unpacking). As root or with passwordless sudo the script installs
them; otherwise it stops and prints the one `sudo apt-get install` line
to run.

**SAW's signature.** The release's `.sig` is signed by key
`07FC90D0C93F5F3B56354E1DCBF4BB4143DB4A3A`, which neither
keys.openpgp.org nor keyserver.ubuntu.com serves, so the pin is the
asset's sha256. Given the key (`SAW_SIGNING_KEY_FILE=key.asc`), the script
verifies the `.sig` too.

The script is tested by `.github/workflows/spark-bootstrap-x86_64.yml`
(on a PR that touches it, or dispatched): on a bare `ubuntu-24.04` runner
with no setup action, and in a plain `ubuntu:24.04` container as root,
which is what measures the packages it must install. Both jobs run it with
`--no-proof`: every phase but `proof` runs, and the phase table reports
`proof` as skipped. Both check that the first run reported every tool
fetched, then run it again (`--no-checks`) and check that the second
reported every tool present and matching the pin, and downloaded and
apt-installed nothing. `llvm-link` is not exercised there (it needs
`GNAT_LLVM_DIR`); `scripts/test-bootstrap-detect.sh`, run by the
workflow's lint job and runnable anywhere, tests the detection of every
tool, `llvm-link` included, against stub tools.

**The proof gate is arm64 only** (`spark-prove.yml`, on
`ubuntu-24.04-arm`). x86_64's provers are slower on some goals, and on
x86_64 six checks run out of time under the committed levels and CI's
allowance: four in `Foundation_Spark.AES.Lemmas` and the postconditions of
`Sub_Bytes` and `Inv_Sub_Bytes` in `Foundation_Spark.AES.Impl`. The
bootstrap's `proof` phase still proves on x86_64 when run without
`--no-proof`, and reports those six as unproved.
