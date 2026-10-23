# #51 AES size and performance, aarch64 macOS (hex): the raw reports

Two back-to-back runs of `spark/scripts/perf-aes.sh` at `3b757f4` (the "dirty" is the README section being written). README "Performance" quotes run 1.

# Run 1

### perf-aes.sh on Darwin arm64, 2026-10-23T00:25:47Z, commit 3b757f4 (dirty)

* CPU: Apple M1 Pro, 10 logical CPUs
* GNAT: gcc (GNAT-FSF-builds) 16.1.0; gprbuild: GPRBUILD 26.0.0 (2026-04-15) (aarch64-apple-darwin24.6.0)
* Rust: rustc 1.95.0 (59807616e 2026-04-14), host aarch64-apple-darwin
* table S-box sources: b967ebb
* load before (1, 5, 15 min): 1.88 2.65 2.52; scheduler: pool ........ 0/8 held;flight nothing running
* load after (1, 5, 15 min): 2.44 2.63 2.52; scheduler: pool ........ 0/8 held;flight nothing running

### Known answers (FIPS-197 Appendix C.1-C.3)

* spark-O2: 9/9 match
* spark-O3: 9/9 match
* spark-O3-checks: 9/9 match
* spark-table-O2: 9/9 match
* spark-table-O3: 9/9 match
* rust-O2: 6/6 match
* rust-O3: 6/6 match
* rust-release: 6/6 match

### Size (bytes, linked executable)

| build | AES text | AES data | wrappers | AES total | executable text |
|---|---:|---:|---:|---:|---:|
| spark-O2 | 5004 | 0 | 16 | 5020 | 39728 |
| spark-O3 | 5632 | 0 | 16 | 5648 | 45808 |
| spark-O3-checks | 6928 | 0 | 28 | 6956 | 46608 |
| spark-table-O2 | 3320 | 512 | 16 | 3848 | 38032 |
| spark-table-O3 | 3856 | 512 | 16 | 4384 | 44016 |
| rust-O2 | 2928 | 814 | 12 | 3754 | 229900 |
| rust-O3 | 3056 | 818 | 12 | 3886 | 236724 |
| rust-release | 2956 | 812 | 12 | 3780 | 246796 |

### Per function (text bytes; data marked)

* **spark-O2**: `aes.impl.inv_sbox_lanes` 880, `aes.impl.expand_key` 848, `aes.impl.sbox_lanes` 784, `aes.impl.decrypt_block_prime` 416, `aes.impl.decrypt_block` 412, `aes.impl.encrypt_block` 388, `aes.impl.inv_mix_byte` 196, `aes.impl.inv_mix_columns` 192, `aes.impl.inv_sub_bytes` 188, `aes.impl.mix_column` 184, `aes.impl.sub_bytes` 180, `aes.impl.mix_columns` 176, `aes.impl.inv_mix_column` 160, `Perf_AES.decrypt` 4, `Perf_AES.decrypt_prime` 4, `Perf_AES.encrypt` 4, `Perf_AES.expand_key` 4
* **spark-O3**: `aes.impl.inv_sbox_lanes` 868, `aes.impl.expand_key` 832, `aes.impl.sbox_lanes` 780, `aes.impl.decrypt_block_prime` 640, `aes.impl.decrypt_block` 608, `aes.impl.inv_mix_columns` 568, `aes.impl.encrypt_block` 448, `aes.impl.inv_mix_byte` 208, `aes.impl.inv_sub_bytes` 192, `aes.impl.sub_bytes` 192, `aes.impl.mix_column` 184, `aes.impl.mix_columns` 112, `Perf_AES.decrypt` 4, `Perf_AES.decrypt_prime` 4, `Perf_AES.encrypt` 4, `Perf_AES.expand_key` 4
* **spark-O3-checks**: `aes.impl.expand_key` 1480, `aes.impl.decrypt_block` 964, `aes.impl.inv_sbox_lanes` 868, `aes.impl.sbox_lanes` 780, `aes.impl.decrypt_block_prime` 776, `aes.impl.encrypt_block` 612, `aes.impl.inv_mix_columns` 568, `aes.impl.inv_mix_byte` 208, `aes.impl.inv_sub_bytes` 192, `aes.impl.mix_column` 184, `aes.impl.sub_bytes` 184, `aes.impl.mix_columns` 112, `Perf_AES.expand_key` 16, `Perf_AES.decrypt` 4, `Perf_AES.decrypt_prime` 4, `Perf_AES.encrypt` 4
* **spark-table-O2**: `aes.impl.expand_key` 824, `aes.impl.decrypt_block` 528, `aes.impl.decrypt_block_prime` 512, `aes.impl.encrypt_block` 512, `aes.impl.inv_s_box (data)` 256, `aes.impl.s_box (data)` 256, `aes.impl.inv_mix_byte` 228, `aes.impl.inv_mix_columns` 192, `aes.impl.mix_column` 188, `aes.impl.mix_columns` 176, `aes.impl.inv_mix_column` 160, `Perf_AES.decrypt` 4, `Perf_AES.decrypt_prime` 4, `Perf_AES.encrypt` 4, `Perf_AES.expand_key` 4
* **spark-table-O3**: `aes.impl.expand_key` 820, `aes.impl.inv_mix_columns` 560, `aes.impl.encrypt_block` 428, `aes.impl.decrypt_block_prime` 380, `aes.impl.decrypt_block` 376, `aes.impl.round` 304, `aes.impl.inv_s_box (data)` 256, `aes.impl.s_box (data)` 256, `aes.impl.inv_round_prime` 248, `aes.impl.inv_mix_byte` 228, `aes.impl.inv_round` 216, `aes.impl.mix_column` 184, `aes.impl.mix_columns` 112, `Perf_AES.decrypt` 4, `Perf_AES.decrypt_prime` 4, `Perf_AES.encrypt` 4, `Perf_AES.expand_key` 4
* **rust-O2**: `KeyExpansion::key_expansion` 896, `Cipher::inv_cipher` 664, `Cipher::cipher` 628, `Cipher::inv_mixcolumns_step` 592, `Cipher::INVSBOX (data)` 258, `Cipher::SBOX (data)` 256, `Cipher::mixcolumns_step` 148, `Cipher::inv_shiftrows::PERM (data)` 128, `Cipher::shiftrows::PERM (data)` 128, `KeyExpansion::RCON (data)` 44, `aes_perf::decrypt` 4, `aes_perf::encrypt` 4, `aes_perf::expand_key` 4
* **rust-O3**: `KeyExpansion::key_expansion` 1004, `Cipher::inv_cipher` 664, `Cipher::cipher` 628, `Cipher::inv_mixcolumns_step` 612, `Cipher::INVSBOX (data)` 262, `Cipher::SBOX (data)` 256, `Cipher::mixcolumns_step` 148, `Cipher::inv_shiftrows::PERM (data)` 128, `Cipher::shiftrows::PERM (data)` 128, `KeyExpansion::RCON (data)` 44, `aes_perf::decrypt` 4, `aes_perf::encrypt` 4, `aes_perf::expand_key` 4
* **rust-release**: `KeyExpansion::key_expansion` 940, `Cipher::inv_cipher` 656, `Cipher::cipher` 624, `Cipher::inv_mixcolumns_step` 592, `Cipher::INVSBOX (data)` 256, `Cipher::SBOX (data)` 256, `Cipher::mixcolumns_step` 144, `Cipher::inv_shiftrows::PERM (data)` 128, `Cipher::shiftrows::PERM (data)` 128, `KeyExpansion::RCON (data)` 44, `aes_perf::decrypt` 4, `aes_perf::encrypt` 4, `aes_perf::expand_key` 4

### Time (ns per call: median, [p25, p75])

| op | spark-O2 | spark-O3 | spark-O3-checks | spark-table-O2 | spark-table-O3 | rust-O2 | rust-O3 | rust-release |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| aes128 expand_key | 718.1 [675.0, 733.9] | 364.5 [336.2, 365.5] | 390.7 [379.7, 412.1] | 505.5 [495.4, 516.2] | 135.6 [124.8, 136.1] | 274.0 [252.7, 274.5] | 390.6 [380.8, 414.3] | 262.3 [241.8, 263.1] |
| aes128 encrypt | 774.5 [738.1, 802.0] | 645.5 [596.3, 648.7] | 628.3 [584.7, 635.6] | 454.5 [440.9, 456.3] | 336.6 [311.5, 338.2] | 418.5 [385.5, 419.4] | 395.4 [383.7, 417.6] | 411.9 [380.0, 413.3] |
| aes128 decrypt | 1400.0 [1343.5, 1451.8] | 1241.3 [1170.0, 1270.2] | 1192.8 [1132.8, 1231.0] | 926.4 [907.6, 934.9] | 774.5 [736.6, 800.5] | 765.7 [708.1, 769.5] | 727.5 [684.1, 743.7] | 743.2 [702.0, 763.1] |
| aes128 decrypt_prime | 1416.7 [1340.9, 1448.7] | 1244.3 [1167.8, 1268.6] | 1225.5 [1163.8, 1263.4] | 942.9 [892.5, 969.6] | 820.3 [762.6, 828.6] |  |  |  |
| aes192 expand_key | 737.4 [690.0, 750.0] | 328.9 [305.0, 331.2] | 360.9 [350.2, 379.8] | 559.8 [530.5, 577.1] | 130.5 [130.5, 141.6] | 307.4 [284.3, 309.1] | 488.3 [450.2, 489.8] | 274.3 [269.5, 293.1] |
| aes192 encrypt | 961.5 [899.7, 976.1] | 763.9 [718.4, 780.5] | 751.4 [705.3, 765.3] | 550.4 [517.8, 563.1] | 407.8 [376.6, 409.7] | 501.4 [462.4, 503.4] | 500.6 [461.5, 502.0] | 469.6 [456.9, 497.0] |
| aes192 decrypt | 1691.5 [1625.1, 1759.9] | 1510.2 [1416.3, 1537.1] | 1443.0 [1372.3, 1491.3] | 1110.1 [1068.9, 1161.8] | 970.2 [897.5, 975.5] | 906.2 [856.0, 929.7] | 879.7 [828.4, 901.5] | 905.4 [850.7, 924.1] |
| aes192 decrypt_prime | 1700.2 [1625.2, 1754.4] | 1497.6 [1414.5, 1536.6] | 1480.0 [1408.5, 1529.2] | 1134.9 [1087.1, 1180.3] | 980.5 [928.8, 1009.8] |  |  |  |
| aes256 expand_key | 906.0 [848.0, 921.5] | 452.7 [424.6, 461.5] | 514.8 [498.4, 541.5] | 662.4 [617.8, 672.1] | 165.4 [165.2, 179.7] | 366.5 [338.1, 367.9] | 549.2 [511.1, 555.5] | 340.1 [324.7, 353.5] |
| aes256 encrypt | 1099.9 [1045.8, 1134.1] | 901.6 [839.5, 912.9] | 866.8 [823.1, 894.7] | 644.4 [615.2, 658.1] | 477.2 [442.9, 481.1] | 565.3 [540.3, 588.0] | 584.1 [538.9, 586.2] | 550.0 [532.7, 579.6] |
| aes256 decrypt | 1998.5 [1913.5, 2066.3] | 1734.4 [1663.5, 1806.3] | 1701.1 [1641.3, 1751.7] | 1333.1 [1259.7, 1369.4] | 1118.4 [1058.7, 1150.7] | 1077.3 [1004.0, 1091.7] | 1039.1 [972.6, 1057.5] | 1036.2 [999.0, 1085.7] |
| aes256 decrypt_prime | 1995.0 [1910.4, 2062.7] | 1742.9 [1660.6, 1803.2] | 1757.4 [1656.2, 1797.9] | 1358.0 [1281.4, 1392.1] | 1143.7 [1095.0, 1189.3] |  |  |  |

min / max per op and build: in each build's .bench.txt (fields: median min p25 p75 max).

### SPARK / Rust (median over median, same optimization level)

| op | spark-O2 / rust-O2 | spark-O3 / rust-O3 | spark-O3-checks / rust-O3 | spark-table-O2 / rust-O2 | spark-table-O3 / rust-O3 |
|---|---:|---:|---:|---:|---:|
| aes128 expand_key | 2.62 | 0.93 | 1.00 | 1.84 | 0.35 |
| aes128 encrypt | 1.85 | 1.63 | 1.59 | 1.09 | 0.85 |
| aes128 decrypt | 1.83 | 1.71 | 1.64 | 1.21 | 1.06 |
| aes128 decrypt_prime | 1.85 | 1.71 | 1.68 | 1.23 | 1.13 |
| aes192 expand_key | 2.40 | 0.67 | 0.74 | 1.82 | 0.27 |
| aes192 encrypt | 1.92 | 1.53 | 1.50 | 1.10 | 0.81 |
| aes192 decrypt | 1.87 | 1.72 | 1.64 | 1.22 | 1.10 |
| aes192 decrypt_prime | 1.88 | 1.70 | 1.68 | 1.25 | 1.11 |
| aes256 expand_key | 2.47 | 0.82 | 0.94 | 1.81 | 0.30 |
| aes256 encrypt | 1.95 | 1.54 | 1.48 | 1.14 | 0.82 |
| aes256 decrypt | 1.86 | 1.67 | 1.64 | 1.24 | 1.08 |
| aes256 decrypt_prime | 1.85 | 1.68 | 1.69 | 1.26 | 1.10 |

# Run 2

### perf-aes.sh on Darwin arm64, 2026-10-23T00:27:22Z, commit 3b757f4 (dirty)

* CPU: Apple M1 Pro, 10 logical CPUs
* GNAT: gcc (GNAT-FSF-builds) 16.1.0; gprbuild: GPRBUILD 26.0.0 (2026-04-15) (aarch64-apple-darwin24.6.0)
* Rust: rustc 1.95.0 (59807616e 2026-04-14), host aarch64-apple-darwin
* table S-box sources: b967ebb
* load before (1, 5, 15 min): 2.40 2.62 2.52; scheduler: pool ........ 0/8 held;flight nothing running
* load after (1, 5, 15 min): 2.71 2.67 2.54; scheduler: pool ........ 0/8 held;flight nothing running

### Known answers (FIPS-197 Appendix C.1-C.3)

* spark-O2: 9/9 match
* spark-O3: 9/9 match
* spark-O3-checks: 9/9 match
* spark-table-O2: 9/9 match
* spark-table-O3: 9/9 match
* rust-O2: 6/6 match
* rust-O3: 6/6 match
* rust-release: 6/6 match

### Size (bytes, linked executable)

| build | AES text | AES data | wrappers | AES total | executable text |
|---|---:|---:|---:|---:|---:|
| spark-O2 | 5004 | 0 | 16 | 5020 | 39728 |
| spark-O3 | 5632 | 0 | 16 | 5648 | 45808 |
| spark-O3-checks | 6928 | 0 | 28 | 6956 | 46608 |
| spark-table-O2 | 3320 | 512 | 16 | 3848 | 38032 |
| spark-table-O3 | 3856 | 512 | 16 | 4384 | 44016 |
| rust-O2 | 2928 | 814 | 12 | 3754 | 229900 |
| rust-O3 | 3056 | 818 | 12 | 3886 | 236724 |
| rust-release | 2956 | 812 | 12 | 3780 | 246796 |

### Per function (text bytes; data marked)

* **spark-O2**: `aes.impl.inv_sbox_lanes` 880, `aes.impl.expand_key` 848, `aes.impl.sbox_lanes` 784, `aes.impl.decrypt_block_prime` 416, `aes.impl.decrypt_block` 412, `aes.impl.encrypt_block` 388, `aes.impl.inv_mix_byte` 196, `aes.impl.inv_mix_columns` 192, `aes.impl.inv_sub_bytes` 188, `aes.impl.mix_column` 184, `aes.impl.sub_bytes` 180, `aes.impl.mix_columns` 176, `aes.impl.inv_mix_column` 160, `Perf_AES.decrypt` 4, `Perf_AES.decrypt_prime` 4, `Perf_AES.encrypt` 4, `Perf_AES.expand_key` 4
* **spark-O3**: `aes.impl.inv_sbox_lanes` 868, `aes.impl.expand_key` 832, `aes.impl.sbox_lanes` 780, `aes.impl.decrypt_block_prime` 640, `aes.impl.decrypt_block` 608, `aes.impl.inv_mix_columns` 568, `aes.impl.encrypt_block` 448, `aes.impl.inv_mix_byte` 208, `aes.impl.inv_sub_bytes` 192, `aes.impl.sub_bytes` 192, `aes.impl.mix_column` 184, `aes.impl.mix_columns` 112, `Perf_AES.decrypt` 4, `Perf_AES.decrypt_prime` 4, `Perf_AES.encrypt` 4, `Perf_AES.expand_key` 4
* **spark-O3-checks**: `aes.impl.expand_key` 1480, `aes.impl.decrypt_block` 964, `aes.impl.inv_sbox_lanes` 868, `aes.impl.sbox_lanes` 780, `aes.impl.decrypt_block_prime` 776, `aes.impl.encrypt_block` 612, `aes.impl.inv_mix_columns` 568, `aes.impl.inv_mix_byte` 208, `aes.impl.inv_sub_bytes` 192, `aes.impl.mix_column` 184, `aes.impl.sub_bytes` 184, `aes.impl.mix_columns` 112, `Perf_AES.expand_key` 16, `Perf_AES.decrypt` 4, `Perf_AES.decrypt_prime` 4, `Perf_AES.encrypt` 4
* **spark-table-O2**: `aes.impl.expand_key` 824, `aes.impl.decrypt_block` 528, `aes.impl.decrypt_block_prime` 512, `aes.impl.encrypt_block` 512, `aes.impl.inv_s_box (data)` 256, `aes.impl.s_box (data)` 256, `aes.impl.inv_mix_byte` 228, `aes.impl.inv_mix_columns` 192, `aes.impl.mix_column` 188, `aes.impl.mix_columns` 176, `aes.impl.inv_mix_column` 160, `Perf_AES.decrypt` 4, `Perf_AES.decrypt_prime` 4, `Perf_AES.encrypt` 4, `Perf_AES.expand_key` 4
* **spark-table-O3**: `aes.impl.expand_key` 820, `aes.impl.inv_mix_columns` 560, `aes.impl.encrypt_block` 428, `aes.impl.decrypt_block_prime` 380, `aes.impl.decrypt_block` 376, `aes.impl.round` 304, `aes.impl.inv_s_box (data)` 256, `aes.impl.s_box (data)` 256, `aes.impl.inv_round_prime` 248, `aes.impl.inv_mix_byte` 228, `aes.impl.inv_round` 216, `aes.impl.mix_column` 184, `aes.impl.mix_columns` 112, `Perf_AES.decrypt` 4, `Perf_AES.decrypt_prime` 4, `Perf_AES.encrypt` 4, `Perf_AES.expand_key` 4
* **rust-O2**: `KeyExpansion::key_expansion` 896, `Cipher::inv_cipher` 664, `Cipher::cipher` 628, `Cipher::inv_mixcolumns_step` 592, `Cipher::INVSBOX (data)` 258, `Cipher::SBOX (data)` 256, `Cipher::mixcolumns_step` 148, `Cipher::inv_shiftrows::PERM (data)` 128, `Cipher::shiftrows::PERM (data)` 128, `KeyExpansion::RCON (data)` 44, `aes_perf::decrypt` 4, `aes_perf::encrypt` 4, `aes_perf::expand_key` 4
* **rust-O3**: `KeyExpansion::key_expansion` 1004, `Cipher::inv_cipher` 664, `Cipher::cipher` 628, `Cipher::inv_mixcolumns_step` 612, `Cipher::INVSBOX (data)` 262, `Cipher::SBOX (data)` 256, `Cipher::mixcolumns_step` 148, `Cipher::inv_shiftrows::PERM (data)` 128, `Cipher::shiftrows::PERM (data)` 128, `KeyExpansion::RCON (data)` 44, `aes_perf::decrypt` 4, `aes_perf::encrypt` 4, `aes_perf::expand_key` 4
* **rust-release**: `KeyExpansion::key_expansion` 940, `Cipher::inv_cipher` 656, `Cipher::cipher` 624, `Cipher::inv_mixcolumns_step` 592, `Cipher::INVSBOX (data)` 256, `Cipher::SBOX (data)` 256, `Cipher::mixcolumns_step` 144, `Cipher::inv_shiftrows::PERM (data)` 128, `Cipher::shiftrows::PERM (data)` 128, `KeyExpansion::RCON (data)` 44, `aes_perf::decrypt` 4, `aes_perf::encrypt` 4, `aes_perf::expand_key` 4

### Time (ns per call: median, [p25, p75])

| op | spark-O2 | spark-O3 | spark-O3-checks | spark-table-O2 | spark-table-O3 | rust-O2 | rust-O3 | rust-release |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| aes128 expand_key | 708.9 [674.9, 733.5] | 364.3 [336.1, 365.2] | 407.7 [379.7, 412.1] | 496.4 [473.9, 515.5] | 135.8 [126.2, 136.1] | 274.2 [252.6, 274.8] | 389.4 [380.8, 413.7] | 258.0 [241.8, 263.0] |
| aes128 encrypt | 778.7 [738.3, 801.1] | 639.9 [596.5, 648.1] | 629.7 [584.4, 636.7] | 455.8 [427.5, 464.6] | 335.8 [311.1, 337.9] | 417.9 [385.4, 419.3] | 414.1 [382.4, 415.9] | 404.9 [379.9, 413.6] |
| aes128 decrypt | 1400.7 [1343.4, 1452.4] | 1230.7 [1169.3, 1271.1] | 1206.9 [1133.0, 1235.2] | 916.9 [877.7, 954.4] | 767.7 [736.7, 801.0] | 762.3 [708.0, 769.4] | 714.5 [684.1, 743.8] | 758.4 [702.2, 763.0] |
| aes128 decrypt_prime | 1399.3 [1334.8, 1447.6] | 1224.5 [1167.7, 1268.1] | 1223.5 [1163.0, 1266.7] | 935.6 [892.1, 969.4] | 805.7 [762.3, 828.4] |  |  |  |
| aes192 expand_key | 747.9 [690.2, 750.4] | 330.6 [305.0, 331.4] | 361.1 [348.8, 379.4] | 562.1 [530.6, 577.4] | 141.7 [130.5, 142.0] | 291.2 [284.1, 309.2] | 486.3 [450.2, 490.0] | 270.1 [269.5, 293.3] |
| aes192 encrypt | 935.1 [900.2, 976.5] | 753.7 [718.4, 781.0] | 737.3 [705.3, 766.8] | 560.2 [517.8, 563.2] | 406.6 [377.3, 409.2] | 500.7 [462.6, 503.1] | 495.8 [459.6, 499.9] | 481.2 [456.9, 497.6] |
| aes192 decrypt | 1700.7 [1627.4, 1762.1] | 1486.8 [1415.9, 1538.7] | 1444.1 [1371.9, 1490.4] | 1142.5 [1070.7, 1161.7] | 959.5 [897.9, 976.1] | 912.7 [855.8, 929.8] | 856.7 [828.3, 900.1] | 892.0 [850.4, 924.2] |
| aes192 decrypt_prime | 1686.7 [1620.5, 1755.3] | 1498.1 [1415.3, 1536.8] | 1485.1 [1409.9, 1530.2] | 1145.2 [1087.5, 1180.4] | 976.3 [929.0, 1009.8] |  |  |  |
| aes256 expand_key | 885.8 [848.5, 921.9] | 454.3 [424.7, 461.3] | 540.0 [498.5, 541.8] | 653.7 [618.3, 672.6] | 176.4 [165.2, 179.7] | 366.5 [338.2, 367.8] | 550.5 [511.4, 555.7] | 325.6 [324.6, 353.4] |
| aes256 encrypt | 1111.8 [1044.2, 1134.7] | 899.0 [839.8, 913.2] | 864.4 [825.2, 894.1] | 646.5 [608.9, 662.5] | 473.0 [442.3, 480.5] | 571.1 [540.5, 587.9] | 582.3 [536.8, 583.9] | 541.2 [532.8, 579.5] |
| aes256 decrypt | 1985.3 [1916.7, 2068.1] | 1746.7 [1663.1, 1804.6] | 1706.2 [1611.4, 1749.9] | 1330.2 [1260.4, 1368.7] | 1119.7 [1059.2, 1150.5] | 1050.9 [1004.5, 1091.0] | 1023.6 [972.7, 1057.7] | 1048.2 [998.7, 1085.3] |
| aes256 decrypt_prime | 1984.7 [1910.4, 2062.6] | 1760.2 [1663.8, 1803.3] | 1723.0 [1657.7, 1797.3] | 1348.1 [1281.5, 1392.3] | 1168.5 [1094.6, 1189.0] |  |  |  |

min / max per op and build: in each build's .bench.txt (fields: median min p25 p75 max).

### SPARK / Rust (median over median, same optimization level)

| op | spark-O2 / rust-O2 | spark-O3 / rust-O3 | spark-O3-checks / rust-O3 | spark-table-O2 / rust-O2 | spark-table-O3 / rust-O3 |
|---|---:|---:|---:|---:|---:|
| aes128 expand_key | 2.59 | 0.94 | 1.05 | 1.81 | 0.35 |
| aes128 encrypt | 1.86 | 1.55 | 1.52 | 1.09 | 0.81 |
| aes128 decrypt | 1.84 | 1.72 | 1.69 | 1.20 | 1.07 |
| aes128 decrypt_prime | 1.84 | 1.71 | 1.71 | 1.23 | 1.13 |
| aes192 expand_key | 2.57 | 0.68 | 0.74 | 1.93 | 0.29 |
| aes192 encrypt | 1.87 | 1.52 | 1.49 | 1.12 | 0.82 |
| aes192 decrypt | 1.86 | 1.74 | 1.69 | 1.25 | 1.12 |
| aes192 decrypt_prime | 1.85 | 1.75 | 1.73 | 1.25 | 1.14 |
| aes256 expand_key | 2.42 | 0.83 | 0.98 | 1.78 | 0.32 |
| aes256 encrypt | 1.95 | 1.54 | 1.48 | 1.13 | 0.81 |
| aes256 decrypt | 1.89 | 1.71 | 1.67 | 1.27 | 1.09 |
| aes256 decrypt_prime | 1.89 | 1.72 | 1.68 | 1.28 | 1.14 |
