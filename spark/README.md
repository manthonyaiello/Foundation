# SPARK implementations

An Alire crate (`foundation_spark`) holding SPARK implementations of
Foundation algorithms, proved against the Cryptol specifications in
`../algorithms`.

## Layout

- `src/common/` – types shared across algorithms (bit sequences, words)
- `src/aes/`, `src/sha2/` – per algorithm: a top spec layer that stays
  semantically close to the Cryptol, plus refinement layers proved
  against it

## Toolchain

Uses gnat_native 16.1.0 and SPARKlib 16.1.0 (for
`SPARK.Higher_Order.Fold` and `SPARK.Big_Integers`). gnatprove 16.1.0
must be on `PATH`; it was installed with `alr install gnatprove` into
`~/.alire/bin`.

```console
$ alr build
$ alr exec -- gnatprove -P foundation_spark.gpr -j0
```
