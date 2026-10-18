## What this changes

<!-- One or two sentences. `Closes #N.` or `Part of #N.`
     For a campaign tick: `Part of the SPARK campaign: targets <BASE> (PR #k) at <sha>.` -->

## What landed

<!-- Each spec-layer unit with the `.cry` file (and FIPS/RFC section) it mirrors. -->

## Board

<!-- `spark/scripts/board.py` output, before -> after, per function: spec,
     FFI-checked, impl proved, SAW.
     Hole counts, zero stated as zero: unproved, assumes, justifications,
     SPARK_Mode Off, warning suppressions. -->

## Checks

- [ ] Trust surface: `spark/scripts/check-trust-surface.sh`
- [ ] Docs: `spark/scripts/check-docs.sh` and `spark/scripts/check-doc-placement.sh`
- [ ] Proof: `spark/scripts/check-proof.sh`, at each unit's committed level
- [ ] FFI: `spark/scripts/check-ffi.sh` (from M0.3), per property `:exhaust` or `:check` and N
- [ ] CI green on the head: `gh pr checks <n> -R manthonyaiello/Foundation`

## Proved where

<!-- Machine, level, wall-clock, and whether the machine was shared. -->

## Skipped, and why

## Trust surface

<!-- Delete this section if spark/scripts/trust-surface.txt is untouched.
     Otherwise: name the site, say why no SPARK formulation works, and report
     it as a hole. -->
