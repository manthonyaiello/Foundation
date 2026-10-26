# Coverage and mutation testing

How much of the executable code the FFI properties run (GNATcoverage,
statement, decision and MC/DC), and which faults they, gnatprove and SAW
catch (one-line mutants). Back to the [README](../README.md).

## Coverage

`scripts/check-coverage.sh` (#49) measures how much of the executable code
the FFI properties run: GNATcoverage's statement, decision and MC/DC
obligations (`--level=stmt+mcdc`) of the units in `coverage/units.txt` (the
executables `AES.Impl`, `AES.Impl.Main`, `SHA2.SHA256_Stream`,
`HMAC.SHA256_Impl`, `SHA2.Functions`, and the non-ghost FFI export units),
under every property of `cryptol/properties.txt`. The ghost spec is out of
scope: it is not code that ships.

```console
$ FFI_JOBS=3 scripts/check-coverage.sh          # every property
$ GNATCOV=/path/to/gnatcov scripts/check-coverage.sh prop_Impl_Dot
```

It needs gnatcov `GNATCOV_VERSION` (`scripts/toolchain-pins.env`; the
Alire crate, `alr -n install gnatcov=26.2.1`, has aarch64 and x86_64 Linux
builds) and what `check-ffi.sh` needs. It

1. installs gnatcov's runtime in `obj/cov/rts` (`gnatcov setup`, once per
   version);
2. instruments and builds the coverage build of the FFI library:
   `foundation_spark_ffi.gpr` with `FOUNDATION_SPARK_FFI_BUILD=coverage`,
   which has its own object and library directories (`obj/cov/`) and one more
   unit, `coverage/foundation_spark_coverage`. gnatprove never reads this
   project, and the FFI check's build is untouched;
3. runs `check-ffi.sh` against that library (`FFI_LIB`, `FFI_OUT`), which
   judges every property as usual;
4. consolidates the traces into `obj/cov/report/`: `summary.txt` (the
   per-unit table and every violation with its explanation), `report.txt`
   (gnatcov's report), `xcov/` (annotated sources) and `xml/`.

**Dumping a trace from Cryptol's process.** gnatcov's `atexit` and
`main-end` triggers are inserted into Ada mains, and Cryptol, which loads the
library by `foreign`, has none. So the instrumentation uses
`--dump-trigger=manual`: `Foundation_Spark_Coverage.Dump` holds
`pragma Annotate (Xcov, Dump_Buffers)`, which gnatcov replaces with the dump,
and the unit's elaboration registers `Dump` with the C library's `atexit`.
The library elaborates itself when Cryptol loads it, so every `cryptol -b`
(one per property) writes its own trace into `obj/cov/traces/` when it exits
(`GNATCOV_TRACE_FILE`). The script fails unless there is one trace per run.

**Explained, or closed.** Every violation must match an entry of
`coverage/explained.txt` (the file, the trimmed text of the line, the
reason), or the script fails. An entry is for code the properties cannot
reach by construction, such as an expression function called only from
contracts, which the FFI build does not execute. A gap in the targeted
tests is closed with a property instead (`prop_Impl_Dot` closed
`AES.Impl.Dot`, which the ciphers never call).

**CI** runs it in `.github/workflows/spark-coverage.yml`, its own workflow,
so it never lengthens the FFI gate: on `ubuntu-24.04` (x86_64), on a PR or a
push to `main` that touches the sources, the properties or the coverage
tooling, and by hand (`workflow_dispatch`). The report is the artifact
`spark-coverage`, and the table goes in the job summary.

## Mutation testing

Coverage says which code the FFI properties run, not which inputs they
try. `scripts/mutation.py` (#104) measures the difference: it applies each
one-line mutant of `mutation/mutants.txt` (84 of them, in `AES.Impl`,
`AES.Impl.Main`, `SHA2.SHA256_Stream`, `HMAC.SHA256_Impl` and
`SHA2.Functions`) in a scratch copy of the checkout, never in the
checkout itself, and records what catches it:

* **FFI**: the library built from the mutated tree, against the
  properties that reach the mutated unit (stopping at the first failure),
  and for a survivor of those, against every property;
* **gnatprove**: `prove.sh -u` on the mutated unit at its committed level,
  the failure sorted into refuted (a counterexample), timeout (the provers
  reached their time limit, no counterexample: not a refutation),
  unproved, or flow;
* **SAW**: `check-saw.sh --print` per mutant (`SAW_LAYERS=impl`), on a
  machine with SAW and GNAT Pro's LLVM back end (`mutation.py saw TREE
  ID ...`, and `saw TREE --baseline` for the unmutated tree).

```console
$ scripts/mutation.py check                      # every mutant applies
$ scripts/mutation.py setup /tmp/mut             # the scratch copy
$ scripts/mutation.py ffi /tmp/mut --baseline    # the controls: the
$ scripts/mutation.py prove /tmp/mut --baseline  #   unmutated tree passes
$ scripts/mutation.py ffi /tmp/mut               # every mutant
$ scripts/mutation.py ffi /tmp/mut --full        # survivors: every property
$ MUTATION_PROVE_WRAP="<a job scheduler's command prefix>" \
    scripts/mutation.py prove /tmp/mut
$ scripts/mutation.py report /tmp/mut            # the table, as Markdown
```

`witness` runs one Cryptol `:check` against a mutant at an input the
properties never try, and `diagnose` re-proves a mutant with more prover
time; both are diagnostics, outside the two columns.

The results (2026-10-23):
the FFI kills 68 of the 84. Of the 16 survivors, 10 are equivalent
mutants, and 6 are real bugs in `SHA256_Stream` that only show on
messages longer than the properties try (from 4 KiB for one, up to 2^53
bytes for another), or on a message array that does not start at 0. gnatprove fails all six at the
assertion each one falsifies, by timeout rather than with a
counterexample. Conversely, the 7 mutants of `SHA2.Functions`, which the
spec and the implementation share, are killed by the FFI and not by
gnatprove, which proves the implementation against the same, mutated,
spec.

SAW (on an x86_64 Linux instance, 2026-10-24) was run on 23 of the mutants: the
16 FFI survivors and the 7 of `SHA2.Functions`. It rejects all 7 of
`SHA2.Functions` (it compares against NSA's Cryptol, as the FFI does): 6
with a counterexample, and Maj's at the 10G memory cap under rme (z3
refutes it at once). It passes all 6 real bugs: its Hash proofs are at
fixed lengths of at most 200 bytes, and `Hash_Chunked` has none, so
gnatprove is the only one of the three that rejects them. It proves 9 of
the 10 equivalent mutants, and fails S14 for a reason of its own, not
the hash's: the mutant copies two null slices, and SAW 1.6 fails at the
poison value GNAT-LLVM's length computation makes there (see "Null
slices" in `saw/sha256_impl.saw`). The unmutated implementation layer
proves (90 proofs, 152 s).
