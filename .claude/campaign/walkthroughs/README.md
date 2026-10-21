# Walkthroughs

Sources of the side-by-side walkthroughs published as claude.ai artifacts.
Each file is a dated snapshot, never edited after the date in its name. To
show a later state, copy the latest snapshot to a new dated file, update the
copy, and publish it as a **new** artifact, so the two pages can be opened
side by side.

| File | Artifact | State of the tree |
|---|---|---|
| `aes-spec-crosswalk-2026-10-20.html` | https://claude.ai/artifact/Xc9HxvFk8EAYitqT3qjhxw | The AES spec layer as of `d2f5972` (the spec unchanged since PR #65), before #68 and #72–#75. Includes Tony's review decisions of 2026-10-20. |
| `aes-spec-crosswalk-2026-10-20-after-80.html` | not published (superseded by the after-#75 copy) | The AES spec layer on the issue-80-aes-generic branch (#80, PR #82): after #68, #72 and #80 (the generic AES_K); before #75. |
| `aes-spec-crosswalk-2026-10-21-after-75.html` | https://claude.ai/artifact/KLycHGxWzBr6ywu5AD4voH | The AES spec layer on `main` at `4431a75` (#75 merged, PR #85): its bodies on the Cryptol prelude in SPARK (`Foundation_Spark.Cryptol`), with the five statements that stay written out and why. |
| `aes-spec-before-after-2026-10-21.html` | https://claude.ai/artifact/T6SGAWL4rSD71gdEcWEAFm | Not a crosswalk: the SPARK spec layer before (`3c956c1`, as reviewed on 2026-10-20) beside after (`4431a75`), definition by definition, with why each changed. |

The files are page bodies: the artifact publisher adds the `<!doctype>`,
`<head>` and `<body>` skeleton. A browser renders them as they are, close
enough to read.
