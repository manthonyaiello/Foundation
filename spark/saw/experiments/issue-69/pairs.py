"""#69: the same Cryptol function proved twice, once of the implementation
and once of the spec layer: results and SAW's summed time per side, from
a check-saw.sh record (saw/results.txt). Leaves are counted on the side
that proves them, once per module load.

Usage: python3 -I pairs.py saw/results.txt
"""
import re
import sys
from collections import defaultdict

PAIRS = [
    ("SHA-256 compression (step)",
     r"^(functions\.|sha256\.logical|sha256\.\"\+\"|sha256_stream\.compress)",
     r"^(functions__|sha256__logical|sha256__(w|t1|t2|step3|rounds__foldl|foldl_step3|Oadd|step))( |$)"),
    ("SHA-256 hash (pad, parse, fold)",
     r"^sha256_stream\.hash",
     r"^(sha256__(hash|pad|zero|small_k|parse|blocks__foldl_take|word_sequences__value)|sequences_of_bits__literal)( |$)"),
    ("HMAC-SHA-256",
     r"^hmac\.",
     r"^hmac__"),
    ("AES key expansion",
     r"^(expand_key|sub_word)",
     r"^(aes\d+__(w|keyexpansion)|keyexpansion__)( |$)"),
    ("AES cipher and inverse",
     r"^(encrypt_block|decrypt_block|round|inv_round|sub_bytes|inv_sub_bytes|shift_rows|inv_shift_rows|"
     r"add_round_key|mix_column|mix_columns|inv_mix_byte|inv_mix_column|inv_mix_columns)( |$)",
     r"^(aes\d+__(cipher|invcipher|invcipher_prime)|cipher__)"),
    ("AES S-box and GF(2^8)",
     r"^(x_times|sbox_lanes|inv_sbox_lanes|sub_byte|inv_sub_byte)( |$)",
     r"^(gf28__|gf2__|sbox__)"),
]

sides = defaultdict(lambda: [0, 0.0])
for line in open(sys.argv[1]):
    if not line.startswith("proved"):
        continue
    t = 0.0
    m = re.search(r", ([0-9.]+) s( with the lines below)?$", line.rstrip())
    if m:
        t = float(m.group(1))
    n = 1
    m = re.search(r"\((\d+) proofs, one per value\)", line)
    if m:
        n = int(m.group(1))
    spec = line.startswith("proved      spec layer: ")
    body = line[len("proved      spec layer: "):] if spec else line[len("proved      "):]
    # Hash's lemmas at the stack bases where HMAC calls it (Pad's To_Bits
    # chains in Hash's own proofs start at Zero's result, below 1000
    # bytes) are HMAC's cost.
    mb = re.search(r"the secondary stack at (\d+) bytes", line)
    if spec and mb and (not body.startswith("sequences_of_bits__literal") or int(mb.group(1)) >= 1000):
        s = sides[("HMAC-SHA-256", True)]
        s[0] += n
        s[1] += t
        continue
    for name, impl_re, spec_re in PAIRS:
        if re.search(spec_re if spec else impl_re, body):
            s = sides[(name, spec)]
            s[0] += n
            s[1] += t
            break

print(f"{'function':35s} {'impl results':>12s} {'impl s':>8s} {'spec results':>12s} {'spec s':>8s} {'time ratio':>10s}")
for name, _, _ in PAIRS:
    i = sides[(name, False)]
    s = sides[(name, True)]
    ratio = s[1] / i[1] if i[1] else float("inf")
    print(f"{name:35s} {i[0]:12d} {i[1]:8.2f} {s[0]:12d} {s[1]:8.2f} {ratio:10.0f}")
