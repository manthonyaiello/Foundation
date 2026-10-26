# Performance

Size and speed of the SPARK AES against NSA's Rust reference AES, on an
arm64 Mac and an x86_64 Linux instance. Back to the
[README](../README.md).

## Performance

`scripts/perf-aes.sh` compares the SPARK AES with the repository's
reference, NSA's Rust `Cipher` and `KeyExpansion` crates
(`../algorithms/AES/rust/`, used unmodified as path dependencies). AES
only: there is no reference SHA-256 or HMAC to compare with.

```console
$ source "$HOME/.cargo/env"
$ alr -n exec -- scripts/perf-aes.sh       # prints and writes obj/perf/perf-report.md
$ PERF_SKIP_BENCH=1 alr -n exec -- scripts/perf-aes.sh   # builds and sizes only
```

It runs on Linux and macOS, x86_64 and arm64 (run so far on aarch64
macOS and x86_64 Linux, below), and needs the crate's
toolchain, cargo, `git`, `nm`, `size` and `python3`. It builds:

| build | flags |
|---|---|
| `spark-O2`, `spark-O3` | `-O2` / `-O3 -gnatn -gnatp -flto -ffunction-sections -fdata-sections`, `pragma Assertion_Policy (Ignore)` (`perf/perf.adc`: no contract, assertion or ghost code), link `-flto` and `-dead_strip` / `--gc-sections` |
| `spark-O3-checks` | the same at `-O3` without `-gnatp`: the run-time checks stay |
| `rust-O2`, `rust-O3` | cargo profiles `perf-o2`/`perf-o3` (`perf/rust/Cargo.toml`): release, `opt-level` 2 / 3, `lto = "fat"`, `codegen-units = 1`; otherwise release defaults (no overflow checks, `panic = "unwind"`). Slice bounds checks stay: Rust cannot turn them off |
| `rust-release` | plain `--release`: `opt-level` 3, no LTO, 16 codegen units |

No `-march`/`target-cpu` on either side: each compiler's default for the
target.

**How it measures.** Each side calls its AES through one non-inlined
wrapper per operation (`perf/src/perf_aes.ads`, `perf/rust/src/lib.rs`),
with the key size read at run time (a `Volatile` / `black_box`): without
that, LTO cloned each SPARK wrapper per constant key size. Each harness
first checks FIPS-197 Appendix C.1–C.3 (encrypt, and decrypt back), then
times each operation in batches of 10 000 chained calls (each output is the
next input): 20 batches of warm-up, then 101 timed batches, on the clock
Rust's `Instant` reads (`clock_gettime_nsec_np (CLOCK_UPTIME_RAW)` on
macOS, `clock_gettime (CLOCK_MONOTONIC)` on Linux). It reports the median
time per call and the quartiles. Sizes are read from the linked
executable's symbols: `nm -S` on Linux, and on macOS (Mach-O symbols have
no size) the linker map (`ld64 -map`). "AES" is every symbol of the crate,
or of NSA's two crates; the harness, GNAT's runtime and Rust's std are not
counted. Rust's anonymous constants are not counted either.

**What the comparison is.** NSA's Rust is a reference implementation, as
the SPARK is: table S-box, `mul_bytes` by shift-and-add, `if` on the
secret in `xTimes`, no T-tables, no hardware AES instructions. The SPARK
is the same algorithm (a table S-box, and `X_Times` by a shift and a
conditional reduction), so the comparison is like for like. Rust's `inv_cipher` undoes the rounds of `cipher` in
reverse order, as `Decrypt_Block_Prime` (InvCipher') does; `Decrypt_Block`
is FIPS's InvCipher. Rust has no counterpart to it, so both are set
against Rust's `decrypt`.

### aarch64, macOS (an arm64 Mac)

Apple M1 Pro (8 performance and 2 efficiency cores), macOS 26.7.1, GNAT
FSF 16.1.0, gprbuild 26.0.0, rustc 1.95.0, at `3b757f4` plus this
section. The SPARK builds below are that run's builds of `src/` at
`b967ebb`, whose `AES.Impl` is the one here (the run's `spark-table-O2`
and `-O3`). Its other SPARK builds, `spark-O3-checks` among them, were
of a constant-time variant of the S-box and are not repeated here, so
there are no `spark-O3-checks` numbers below. Two full runs, 2026-10-23 00:25 UTC, back to back; the numbers are
the first's; the second's medians are within 3% of them in 80 of 87 cells
and within 9% in all (the largest moves are `Expand_Key`'s, the shortest
operation). **A
shared desktop, not an idle machine**: the 1-minute load was 1.9 before and
2.4–2.7 after (the benchmark is one of it), no proof was running, and desktop daemons used about one core between them. macOS
cannot pin a thread to a core; the quartiles are 5–8% apart, against 1%
(the median cell) on the idle x86_64 Linux instance below.

Size (bytes):

| build | AES text | AES data | wrappers | executable text (with runtime / std) |
|---|---:|---:|---:|---:|
| `spark-O2` | 3320 | 512 | 16 | 38 032 |
| `spark-O3` | 3856 | 512 | 16 | 44 016 |
| `rust-O2` | 2928 | 814 | 12 | 229 900 |
| `rust-O3` | 3056 | 818 | 12 | 236 724 |
| `rust-release` | 2956 | 812 | 12 | 246 796 |

* Per function at `-O3`, Rust: `key_expansion` 1004, `cipher` 628,
  `inv_cipher` 664, `inv_mixcolumns_step` 612.
* The SPARK's code is 26% larger than the Rust's at `-O3` (3856 against
  3056 bytes), 13% with the data counted (4368 against 3874). Its data
  is the two 256-byte S-box tables.
* The executables differ by 190 KB: Rust's std (formatting, panics,
  unwinding) against GNAT's runtime. That is the harness, not the AES.

Time (ns per call, median; first and third quartile in the report):

| op | `spark-O3` | `rust-O3` | `spark-O2` | `rust-O2` |
|---|---:|---:|---:|---:|
| AES-128 `Expand_Key` | 135.6 | 390.6 | 505.5 | 274.0 |
| AES-128 encrypt | 336.6 | 395.4 | 454.5 | 418.5 |
| AES-128 decrypt (`Decrypt_Block`) | 774.5 | 727.5 | 926.4 | 765.7 |
| AES-128 `Decrypt_Block_Prime` | 820.3 | 727.5 | 942.9 | 765.7 |
| AES-192 `Expand_Key` | 130.5 | 488.3 | 559.8 | 307.4 |
| AES-192 encrypt | 407.8 | 500.6 | 550.4 | 501.4 |
| AES-192 decrypt (`Decrypt_Block`) | 970.2 | 879.7 | 1110.1 | 906.2 |
| AES-256 `Expand_Key` | 165.4 | 549.2 | 662.4 | 366.5 |
| AES-256 encrypt | 477.2 | 584.1 | 644.4 | 565.3 |
| AES-256 decrypt (`Decrypt_Block`) | 1118.4 | 1039.1 | 1333.1 | 1077.3 |

(The Rust columns of the `Decrypt_Block_Prime` row repeat Rust's one
decryption. `rust-release` is within 7% of `rust-O3` except at
`Expand_Key`, where it is 33–44% faster: see below.)

What it shows, at `-O3`:

* **The SPARK is faster than the Rust on encryption and key expansion,
  and slightly slower on decryption**: encrypt 0.81–0.85×, key expansion
  0.27–0.35×, decrypt 1.06–1.13×.
* **`-O2` against `-O3` matters more to the SPARK than to the Rust**: the
  SPARK at `-O2` is 1.1–1.4× slower than at `-O3` on the ciphers and
  3.7–4.3× on `Expand_Key`; the Rust is within 6% on the ciphers,
  except that Rust's `key_expansion` is 1.4–1.6× *slower* at `opt-level`
  3 than at 2 (and with the release default's 16 codegen units and no LTO,
  as fast as at 2). Not investigated further.

### x86_64, Linux (an x86_64 Linux instance)

Intel Xeon (8 vCPUs), Ubuntu 24.04, GNAT FSF
16.1.0, gprbuild 26.0.0, rustc 1.95.0, at `6023e8a`, the script
unmodified. As above, the SPARK builds below are that run's builds of
`src/` at `b967ebb`. Two full runs, 2026-10-23 18:02 UTC, back to back; the
numbers are the first's; the second's medians are within 3% of them in
86 of 87 cells and within 5.4% in all, and the sizes are identical. **An
idle machine**: nothing else ran on it, the 1-minute load was 0.65 before
and 0.97 after. The quartiles are 1% apart in the median cell; the 8 of
87 cells wider than 3% (up to 9%) are all in the SPARK columns below.

Size (bytes):

| build | AES text | AES data | wrappers | AES total | executable text (with runtime / std) |
|---|---:|---:|---:|---:|---:|
| `spark-O2` | 726 | 512 | 2856 | 4094 | 274 665 |
| `spark-O3` | 1187 | 512 | 5416 | 7115 | 280 169 |
| `rust-O2` | 3405 | 812 | 15 | 4232 | 276 810 |
| `rust-O3` | 3535 | 812 | 15 | 4362 | 281 034 |
| `rust-release` | 3339 | 812 | 18 | 4169 | 291 427 |

* **Read "AES total" here, not "AES text".** On Linux GCC's LTO inlines
  `Expand_Key`, `Encrypt_Block`, `Decrypt_Block` and
  `Decrypt_Block_Prime` into `Perf_AES`'s wrappers (on macOS they stayed
  4-byte branches), so most of the SPARK AES is counted under
  "wrappers". Rust's wrappers are tail calls; its `key_expansion` is
  1412, `cipher` 645, `inv_cipher` 643.
* At `-O3` the SPARK AES is 1.6× the Rust's (7115 against 4362 bytes):
  GCC unrolls its encryption into a 1988-byte `Perf_AES.Encrypt`. At
  `-O2` it is the smaller (4094 against 4232).
* Both sides link their runtimes statically here, and the executables
  are within 17 KB of each other: the 190 KB gap on macOS is not there.

Time (ns per call, median; first and third quartile in the report):

| op | `spark-O3` | `rust-O3` | `spark-O2` | `rust-O2` |
|---|---:|---:|---:|---:|
| AES-128 `Expand_Key` | 132.1 | 310.9 | 202.3 | 251.3 |
| AES-128 encrypt | 221.7 | 421.9 | 463.8 | 419.9 |
| AES-128 decrypt (`Decrypt_Block`) | 680.0 | 671.7 | 878.2 | 669.2 |
| AES-128 `Decrypt_Block_Prime` | 677.6 | 671.7 | 878.3 | 669.2 |
| AES-192 `Expand_Key` | 140.8 | 356.8 | 211.9 | 283.0 |
| AES-192 encrypt | 264.6 | 501.5 | 565.1 | 501.1 |
| AES-192 decrypt (`Decrypt_Block`) | 835.1 | 811.2 | 1062.0 | 807.4 |
| AES-256 `Expand_Key` | 172.0 | 415.6 | 269.1 | 334.9 |
| AES-256 encrypt | 302.4 | 588.3 | 665.1 | 583.0 |
| AES-256 decrypt (`Decrypt_Block`) | 970.1 | 941.3 | 1251.5 | 945.5 |

(The Rust columns of the `Decrypt_Block_Prime` row repeat Rust's one
decryption. `rust-release` is within 3% of `rust-O3` except at
`Expand_Key`, where it is 25–27% faster.)

What it shows, at `-O3`, against aarch64:

* **The SPARK is faster than the Rust on encryption and key expansion,
  by more than on aarch64, and level on decryption**: encrypt 0.51–0.53×
  (aarch64 0.81–0.85×), key expansion 0.39–0.42× (0.27–0.35×), decrypt
  1.01–1.03× (1.06–1.13×).
* **`-O2` against `-O3`**: the SPARK at `-O2` is 2.1–2.2× slower on
  encrypt, 1.3× on decrypt and 1.5–1.6× on `Expand_Key` (aarch64:
  1.4×, 1.1–1.2× and 3.7–4.3×). Rust's `key_expansion` is again slower
  at `opt-level` 3 than at 2, by 1.24–1.26× (aarch64 1.4–1.6×).
