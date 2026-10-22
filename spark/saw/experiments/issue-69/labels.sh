#!/usr/bin/env bash
# labels.sh OUT_DIR -- one line per "== label" of an experiment's saw.log:
# how many "Time:" lines followed it, the first, and the last (for a
# label printed before a timed group, the last is the group's total),
# then the run's wall-clock and peak RSS (time.txt).
awk '/^== / { lab = substr($0, 4); if (!(lab in n)) order[++k] = lab; n[lab] += 0 }
     /^Time: / && lab != "" { t = $2; if (n[lab] == 0) first[lab] = t; last[lab] = t; n[lab]++ }
     END { for (i = 1; i <= k; i++) { l = order[i]; printf "%-75s %4d  first %-14s last %s\n", l, n[l], first[l], last[l] } }' "$1/saw.log"
grep -E 'Elapsed|Maximum resident|Exit status' "$1/time.txt"
