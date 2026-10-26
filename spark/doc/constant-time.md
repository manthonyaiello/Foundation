# Constant time

What "constant time" means for this crate, the audit of the executable
code, the bitsliced AES S-box that replaced the table lookups, and the
three checks: the object code, secret taint under Valgrind, and timing.
Back to the [README](../README.md).

## Constant time

After SPARKNaCl, the executable code must take the same
time, and touch the same memory, whatever the secrets are. Functional proof
says nothing about timing: a table-driven AES is correct, and its table
lookups leak the key through the cache.

**What is secret, what is public.** Secret: AES keys, round keys, plaintext
and ciphertext blocks; SHA-256 message bytes and the hash state; HMAC keys
and message bytes. Public: every length (of a key, a message, a chunk), the
key size `K`, `Nk (K)` and `Nr (K)`, loop counters and round numbers, and
whatever is computed from public values only.

**The rule.** In code that handles secrets:

1. no branch on a secret: no `if`, `case`, `while` or `exit when`
   condition, no `and then`/`or else`, and no `if` expression, whose value
   depends on a secret;
2. no index on a secret: no array index, and so no memory address, computed
   from a secret (a table lookup, `T (B)`, is the classic case);
3. no early exit on a secret, such as a comparison that returns at the
   first difference (compare by OR-ing the XORs of all bytes instead);
4. no operation whose time depends on its operands on the targets:
   division and `mod` by a secret, and shift or rotate amounts that are
   secret. Bitwise operations, addition, and multiplication on aarch64 and
   x86_64 are fine.

Where a value must be chosen by a secret, select with a mask: `0 - Bit`
is all ones or all zeros, and `(A and M) or (B and not M)` picks without a
branch.

**The audit** (the source at `b967ebb`, every executable unit):

| site | secret? | outcome |
|---|---|---|
| `AES.Impl.Sub_Byte`, `Inv_Sub_Byte`: `S_Box (B)`, `Inv_S_Box (B)` | index on the state and key bytes | **removed**: a bitsliced circuit, below |
| `Sub_Bytes`, `Inv_Sub_Bytes`, `Sub_Word` (and so `Round`, `Inv_Round`, `Inv_Round_Prime`, `Expand_Key`, the ciphers) | the same lookups, through `Sub_Byte` | **removed** with it |
| `AES.Impl.X_Times`: `if B >= 16#80# then 16#1b# else 0` | a branch on a state byte, in every `MixColumns` | **removed**: `16#1b# and (0 - B >> 7)` (the old code compiled to a select on aarch64 at `-O3`, but nothing in the source required it) |
| `AES.Impl.Dot`: `if` on each bit of `C`, `if T >= 256` | branches on both operands (not on any cipher path; exported to callers) | **removed**: masks. At `-O3` on aarch64 the old code was selects, except one real branch: `tbz w1, #0` on `C`'s low bit |
| `AES.Impl.Expand_Key`: `if I < Nk`, `I mod Nk = 0`, `I mod Nk = 4 and Nk > 6`, `Rcon (I / Nk)`, `Ws (I - Nk)` | `I` and `K` | public: kept |
| `Encrypt_Block`, `Decrypt_Block`, `Decrypt_Block_Prime`: the round loop, `W (R)` | `Nr (K)`, `R` | public: kept |
| `SHA256_Stream.Compress`: two loops of 64, `K_256 (T)`, `Sched (T - 2)` ... | `T` | public: kept; `Ch`, `Maj`, `Σ`, `σ` are bitwise with constant rotations |
| `SHA256_Stream.Update`, `Final`, `Hash`, `Hash_Chunked`, `Load_Block`: buffer fill, `Count mod 64`, `if R < 56`, the block loop | lengths and offsets | public: kept |
| `HMAC.SHA256_Impl.Init_Key`: `if Key'Length > 64` | the key's length | public: kept |
| HMAC: no tag comparison exists | | a future `Verify` must follow rule 3 |

The ghost code (spec layer, lemmas) does not run and is out of scope.

**The S-box.** `Sub_Byte` and `Inv_Sub_Byte` compute the S-box with Boyar
and Peralta's depth-16 circuit ("A small depth-16 circuit for the AES
S-box", SEC 2012: 128 gates, 34 AND and 94 XOR/XNOR), and the inverse as
`A⁻¹ ∘ SBox ∘ A⁻¹` with `A⁻¹` the inverse of the S-box's affine map, as
BearSSL's `aes_ct` does. Each gate is a bitwise operation on a 64-bit word
holding eight byte lanes (SWAR bitslicing: bit `k` of each lane is moved to
the lane's bit 0 by a shift and a mask), so one evaluation gives eight
S-box entries: `Sub_Bytes` evaluates it twice per round, `Sub_Word` once.
Why this one:

* *a full-table scan with masking* reads all 256 entries per byte: easy to
  prove, but 256 loads per byte, 4096 per round;
* *an arithmetic S-box* (`b^254` by square-and-multiply in GF(2^8), then
  the affine map) needs a constant-time multiplier and a proof that `b^254`
  is the spec's `GF2.Inverse`, which is the slow `SBoxCorrect` proof over
  again;
* *the bitsliced circuit* is the fastest of the three, the standard choice
  (BearSSL, the Käsper–Schwabe line of work), and, as it turned out, the
  cheapest to prove: gnatprove proves it equal to the spec's tables
  directly.

The proof: the body-local `SBox_Lanes` and `Inv_SBox_Lanes` have the
postcondition that each lane of the result is `Spec.SBox.SBox`
(`InvSBox`) of the same lane of the input; the provers bit-blast the
circuit against the table, at level 2. `Sub_Byte`, `Inv_Sub_Byte`,
`Sub_Bytes`, `Inv_Sub_Bytes` and `Sub_Word` keep their contracts, so
nothing above them changed. The executable tables `S_Box` and `Inv_S_Box`
are gone.

**The cost** (`ct_bench`, release build, on an aarch64 Linux container with
nothing else proving, the better of two runs of best-of-7; before = `main`
at `b967ebb`, table S-box):

| ns per call | before | after | ratio |
|---|---:|---:|---:|
| AES-128 `Encrypt_Block` | 233.1 | 382.1 | 1.64 |
| AES-128 `Decrypt_Block` | 426.3 | 607.4 | 1.42 |
| AES-128 `Expand_Key` | 57.7 | 168.1 | 2.91 |
| AES-192 `Encrypt_Block` | 280.1 | 460.0 | 1.64 |
| AES-192 `Decrypt_Block` | 519.3 | 735.0 | 1.42 |
| AES-192 `Expand_Key` | 49.4 | 138.7 | 2.81 |
| AES-256 `Encrypt_Block` | 328.4 | 538.2 | 1.64 |
| AES-256 `Decrypt_Block` | 612.4 | 864.0 | 1.41 |
| AES-256 `Expand_Key` | 70.1 | 212.6 | 3.03 |
| SHA-256, per byte of 64 KiB (unchanged code) | 3.08 | 3.08 | 1.00 |

AES-128 encryption goes from 14.6 to 23.9 ns per byte. `Expand_Key`
pays most, relatively: each `Sub_Word` evaluates the whole 8-lane circuit
for 4 bytes, against 4 loads before.

On an x86_64 Linux instance (Intel Xeon, 8 CPUs, GNAT 16.1 at `-O3
-gnatn`; the better of two runs of best-of-7, on 2026-10-21, with a
sibling SAW job on one core, load average 1.3–1.9):

| ns per call | before | after | ratio |
|---|---:|---:|---:|
| AES-128 `Encrypt_Block` | 310.6 | 510.1 | 1.64 |
| AES-128 `Decrypt_Block` | 656.9 | 1013.6 | 1.54 |
| AES-128 `Expand_Key` | 129.6 | 274.7 | 2.12 |
| AES-192 `Encrypt_Block` | 374.4 | 614.5 | 1.64 |
| AES-192 `Decrypt_Block` | 795.3 | 1225.3 | 1.54 |
| AES-192 `Expand_Key` | 138.1 | 257.5 | 1.86 |
| AES-256 `Encrypt_Block` | 440.0 | 717.6 | 1.63 |
| AES-256 `Decrypt_Block` | 934.2 | 1439.0 | 1.54 |
| AES-256 `Expand_Key` | 163.2 | 344.1 | 2.11 |
| SHA-256, per byte of 64 KiB (unchanged code) | 4.09 | 4.09 | 1.00 |

AES-128 encryption goes from 19.4 to 31.9 ns per byte. The encryption
ratio is the same as on aarch64; decryption and `Expand_Key` cost
relatively less here.

**Checking it.** `scripts/check-ct.sh` builds `ct/ct.gpr` (the crate's AES,
SHA-256 and HMAC sources at Alire's release level, `-O3 -gnatn`, default
runtime checks) and:

1. **the object code**: disassembles the release objects (`objdump -d -r`)
   and runs `scripts/check-ct-asm.py`, which fails if any of the 21
   straight-line AES functions (`X_Times`, the S-box functions, the round
   functions; they see secrets and have no public loop) has a conditional
   or indirect branch or an indexed load or store, and lists the sites of
   the loop functions for review;
2. **secret taint** (ctgrind-style, when `valgrind` is on `PATH`):
   `ct_grind` marks the secrets undefined for Memcheck through its client
   requests, and Memcheck must report no branch and no address computed
   from them; a control run with one deliberate table lookup must report
   one;
3. **timing** (dudect-style): `ct_dudect TARGET SAMPLES` compares a
   fixed-input class with a random-input class by Welch's t-test (Reparaz,
   Balasch and Verbauwhede, DATE 2017); `|t|` above 4.5 is evidence of a
   leak. Reported, not enforced: timing on a shared machine is evidence,
   and a `|t|` below 4.5 shows only that this many samples saw nothing.

Results on an aarch64 Linux container (GNAT 16.1 at `-O3 -gnatn`), before
(`b967ebb`) and after:

* **Object code.** Before: 86 indexed loads in the straight-line
  functions (`ldrb w0, [x1, w0, uxtw]` in `Sub_Byte`, 16 in each of
  `Sub_Bytes`, `Inv_Sub_Bytes`, `Round`, `Inv_Round`, `Inv_Round_Prime`,
  4 in `Sub_Word`), and the same lookups inlined into `Encrypt_Block`,
  `Decrypt_Block` and `Expand_Key`; and in `Dot`, a `tbz` on a bit of its
  secret operand: the compiler turned seven of the source's eight `if`s
  into selects and kept the last one as a branch. After: **0** in the
  straight-line functions, and no conditional branch. `X_Times` is `sbfx`,
  `and`, `eor`; `Dot` has no branch or indexed access left. In the
  loop functions every remaining site tests or indexes by a public value:
  the round loop and `W (R)` in the ciphers, `I`, `Nk` and the `Rcon`
  switch table (indexed by `I / Nk`) in `Expand_Key`, the two loop
  back-edges of SHA-256 `Compress`, and lengths and offsets in `Update`,
  `Final`, `Load_Block`, `Hash_Chunked` and HMAC's `Init_Key`.
* **Timing** (`ct_dudect`, max `|t|` over the raw and six cropped tests):

  | target | samples | before | after |
  |---|---:|---:|---:|
  | `aes128_encrypt` (plaintext secret) | 2 000 000 | **17.6** | 1.2 |
  | `aes128_decrypt` (ciphertext secret) | 2 000 000 | **6.5** | 2.1 |
  | `aes128_key` (key secret) | 1 000 000 | **6.5** | 1.9 |
  | `sha256` (64-byte message) | 1 000 000 | 1.5 (2 000 000) | 0.6 |
  | `hmac_key` (32-byte key) | 1 000 000 | | 0.9 |

  The table S-box leaks measurably here even with its 256-byte tables hot
  in L1 (a fixed input reuses the same lines and banks); the bitsliced one
  shows nothing at these sample counts. The `evict` mode (64 MiB written
  before each measurement) saw nothing in 20 000 samples of the table
  version: eviction makes every measurement slow and noisy, and only the
  first of a batch of four calls starts cold.
* **Secret taint** (`ct_grind`): not run on aarch64. There was no
  Valgrind on the container (and no system C toolchain to build one);
  `ct_grind` builds and runs natively, where its requests do nothing.
  See x86_64 below.

Results on an x86_64 Linux instance (Intel Xeon, Ubuntu 24.04, GNAT 16.1 at
`-O3 -gnatn`, GNAT Pro 27's `objdump` 2.46, Valgrind 3.22.0), before
(`b967ebb`, with `ct/` and the two scripts copied in) and after, on
2026-10-21. The machine was shared with a SAW job on one of its 8 cores
(load average 0.3–1.9 during the runs):

* **Object code.** Before: the same **86** indexed loads in the
  straight-line functions as on aarch64 (`movzbl (%rax,%rdi,1),%eax` in
  `Sub_Byte` and `Inv_Sub_Byte`, 16 in each of `Sub_Bytes`,
  `Inv_Sub_Bytes`, `Round`, `Inv_Round`, `Inv_Round_Prime`, 4 in
  `Sub_Word`), the lookups inlined into the ciphers and `Expand_Key`, and
  in `Dot` one `je` on its secret operand. The old `X_Times` compiled to
  `cmovs`, a select, as on aarch64. After: **0** in the straight-line
  functions, no conditional branch, and `Dot` has no site left. The loop
  functions' sites are the same public ones as on aarch64 (the `Rcon`
  switch table, `CSWTCH`, indexed by `I / Nk`). The first x86 run showed that `check-ct-asm.py` read
  objdump's prefix words (`data16 cs nopw 0x0(%rax,%rax,1)`, alignment
  padding) as opcodes: it listed the padding as indexed accesses in the
  loop functions, and would have missed a `notrack jmp *%rax`. It now
  skips the prefixes, and counts `loop`/`loope`/`loopne` as branches.
* **Secret taint** (`ct_grind` under Memcheck). After: **0 errors** on the
  secrets, and the control run reports its table lookup (1 error, "Use of
  uninitialised value of size 8"). Before: **1855 errors from 107
  contexts**, in `Sub_Byte`, `Inv_Sub_Byte`, `Round`, `Inv_Round`,
  `Inv_Round_Prime`, `Expand_Key`, `Encrypt_Block`, `Decrypt_Block` and
  `Decrypt_Block_Prime` ("Use of uninitialised value of size 8": an
  address from a secret), and one in `Dot` ("Conditional jump or move
  depends on uninitialised value(s)": the `je` above). This is the first
  run of `ct_grind`'s x86_64 client requests: they work.
* **Timing** (`ct_dudect`, max `|t|` over the raw and six cropped tests;
  `check-ct.sh` at 1 000 000 samples, then three more runs at 2 000 000):

  | target | before, 1M | before, 2M (4 runs) | after, 1M | after, 2M (4 runs) |
  |---|---:|---:|---:|---:|
  | `aes128_encrypt` | 3.0 | **30.9**, **19.1**, 2.2, **32.9** | 2.2 | 1.4, 1.3, 1.4, 1.4 |
  | `aes128_decrypt` | **13.1** | 2.7, 3.3, 1.5, **7.9** | 1.3 | 0.9, 1.9, 1.6, 1.9 |
  | `aes128_key` | **15.2** | **9.4**, **11.8**, **93.4**, **111.9** | 1.4 | 1.7, 2.0, 1.3, 2.1 |
  | `sha256` | 1.3 | 1.3, 1.2, 2.3 (3 runs) | 1.3 | 1.1, 1.2, 0.8 (3 runs) |
  | `hmac_key` | 1.6 | 1.4, 1.6, 1.4 (3 runs) | 1.3 | 1.3, 1.1, 1.3 (3 runs) |

  The table S-box leaks on x86_64 too, but not in every run: 10 of its
  15 AES runs exceed 4.5. The bitsliced one stays below 2.3 in all 15
  of its AES runs.

**What SPARK can and cannot say about it.** gnatprove proves values, not
time or addresses: no contract states "this runs in constant time", and
there is no secret/public label on data. What it does give:

* the rewrite is free of functional risk: the circuit is proved equal to
  the table it replaces, so a constant-time rewrite cannot break AES;
* absence of run-time errors, so the release build may suppress checks
  (`-gnatp`) and lose the compare-and-branch of each check on a secret
  value (none survives in the straight-line functions anyway, at `-O3` with
  checks on);
* `Depends` contracts state which outputs depend on which inputs, but not
  how: they do not tell a data flow from a control flow, so they cannot
  forbid rule 1.

What could be enforced in Ada itself, and is not done here: a private
"secret byte" type exporting only bitwise and arithmetic operations, with
no relational operators and no conversion to an index type, would make
rules 1 and 2 compile-time errors. It would touch every executable unit
and its bridge to the spec, so it is left as a follow-up. The rule is
checked instead on the object code (`check-ct-asm.py`), by Memcheck
(`ct_grind`), and by statistics (`ct_dudect`).
