# C512 16-Block Inter-Block 1B E4M3 Stream + ViT Entry/Exit & Downsample Byte Edges (`c512-byte-stream-20261014`)

## 1. Motivation & Cross-Kernel Traffic Audit

Following Campaign 6 (`vit-inter-byte-20261014`, `HIP_VIT_INTER_BYTE=1`, which eliminated the 7 inter-block `vit_pack_input` launches and `49.28 MB/frame` of `float32 <-> uint8` traffic inside ViT blocks `31..38`), a full-network cross-kernel audit identified the remaining boundaries where a producer kernel quantizes its accumulator onto the exact FP8 E4M3 lattice (`F(Hrtz(acc))`), expands it back to 4B `float32` in global memory, and the consumer immediately re-quantizes or reads that lattice value:

1. **Bit 1 (`2`) — Downsample `C64 -> C128` (Block 8 -> 9) & `C128 -> C256` (Block 14 -> 15) Byte Edge**:
   - `mh_pool_project_group_c64_hin` (`480x288x128`) and `mh_pool_project_group_c128_hin` (`240x144x256`) already compute `byte_F(Hrtz(acc))` and convert it back to 4B FP32 (`fp8_to_f32(byte_F(Hrtz(acc)))`) before storing `70.78 MB` and `35.39 MB` of FP32 outputs, while Block 9 (`c128_wave2`) and Block 15 (`c256_wave2`) already have `*_bi_bo[_w16]` exports ready to consume 1B E4M3 directly.
   - Exporting `mh_pool_project_group_c64_hin_out8` and `mh_pool_project_group_c128_hin_out8` cuts Down(8)+Block 9 and Down(14)+Block 15 boundary traffic by 4x, saving **`59.72 MB/frame`**.

2. **Bit 2 (`4`) — ViT Entry (`Down(30) -> Gather -> Block 31`) & Exit (`Block 38 -> Gather -> Up(39)`) Byte Edge**:
   - At ViT Entry, `mh_pool_project_group_c512` (`Down(30)`) quantizes to E4M3 and writes `1.41 MB` of 4B FP32 (`30x18x1024`), `vit_gather` copies `1.41 MB` of 4B FP32 (`600x256`), and Block 31 launches the last remaining `vit_pack_input` kernel to pack it back to `0.35 MB` of 1B E4M3.
   - At ViT Exit, Block 38 (`vit_stream_project_n64_bb_compactw_w16`) writes `1.41 MB` of 4B FP32, `vit_gather` un-gathers `1.41 MB` of 4B FP32, and `Up(39)` (`decoder_project2x_h16w[_byteout]_w`) reads every token 32 times across output tiles (`45.16 MB` of 4B FP32 reads) and immediately calls `df_pack8` (`v_cvt_pk_fp8_f32`) to convert it back to 1B E4M3 for WMMA!
   - Exporting `mh_pool_project_group_c512_out8`, `vit_gather_b8`, `decoder_project2x_h16w_w_bin`, and `decoder_project2x_h16w_byteout_w_bin`, and running Block 38 with `bout=true` **eliminates the final `vit_pack_input` launch in the entire network (`154 -> 153` launches/frame)** and saves **`41.61 MB/frame`** of global traffic + 128 `v_cvt_pk_fp8_f32` instructions per wave in `Up(39)`.

3. **Bit 3 (`8`) — C512 16-Block Inter-Block 1B E4M3 Stream (`Down(22) -> Blocks 23..30` & `Up(39) -> Blocks 40..47`)**:
   - Across all 16 C512 blocks (`23..30` in encoder, `40..47` in decoder, `60x36 = 2,160` tokens, `C = 512`), `mh_attention_project_frag_c512_w16_u4` on blocks `23..29` and `40..46` (`post = 0`), `Down(22)` (`mh_pool_project_group_c256`), and `Up(39)` (`decoder_project2x_h16w_byteout_w`) all quantize their outputs onto the exact E4M3 lattice (`F(Hrtz(acc))`), only to write `4.42 MB` of 4B FP32 per block (`70.78 MB/frame` write).
   - Then in every single C512 block (`23..30` and `40..47`), `split_ffn_one_w2f8_w16` reads the `4.42 MB` FP32 tensor 8 times across the 8 channel-group workgroups (`8 x 4.42 MB = 35.39 MB` read per block = `566.23 MB/frame` across 16 blocks!) and executes 64 `v_cvt_pk_fp8_f32` instructions per wave (`c5d_pack8f`) to convert those exact E4M3 floats back into E4M3 bytes! Meanwhile `split_projection_frag_w16` reads another `4.42 MB` per block (`70.78 MB/frame`) for the skip connection.
   - Exporting `mh_pool_project_group_c256_out8`, `mh_attention_project_frag_c512_w16_u4_bout`, `split_ffn_one_w2f8_w16_bin`, `split_projection_frag_w16_bskip`, and enabling `decoder_project2x_h16w_byteout_w[_bin]` for `1024 -> 512` (`Up(39)`) keeps the entire 16-block C512 stream in 1B E4M3 (except Block 30's `post = 3` raw `Hrtz` output for `skips[4]`/`Down(30)` and Block 47's output for `Up(48)`), cutting C512 inter-block L2/DRAM traffic by **4x (`707.79 MB -> 176.95 MB`, saving `530.84 MB/frame`)** and reducing the runtime pool size from **`277.1 MiB` to `276.0 MiB` (`-1.1 MiB`)**.

4. **Bit 4 (`16`, Opt-In) — Transposed-WMMA `split_projection_frag_w16_nof32[_bskip]` + `mh_attention_project_frag_c512_w16_u4_fb8[_bout]`**:
   - Also implemented and verified a transposed-WMMA (`B^T * A^T`) variant that eliminates the intra-block `4.42 MB` FP32 `ffn` tensor write/read across all 16 C512 blocks (`141.56 MB/frame`) by reading `ffn8` E4M3 tiles directly in `mh_attention_project_frag_c512_w16_u4_fb8[_bout]`.

---

## 2. ISA Verification (`gfx1201`)

| Kernel | VGPRs | LDS (B) | Spills | `ld_b128` | `ld_b64` | `ld_b32` | `ld_u8` | `st_b128` | `st_b32` | `st_b8` | `cvt_pk_fp8_f32` | `cvt_f32_fp8` |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `split_ffn_one_w2f8_w16` (stock) | 124 | 0 | 0 | 24 | 0 | 0 | 0 | 0 | 0 | 32 | 80 | 0 |
| **`split_ffn_one_w2f8_w16_bin`** | **124** | **0** | **0** | **16** | **4** | **0** | **0** | **0** | **0** | **32** | **64 (`-16`)** | **0** |
| `mh_attention_project_frag_c512_w16_u4` | 101 | 0 | 0 | 16 | 8 | 36 | 0 | 0 | 32 | 0 | 32 | 32 |
| **`mh_attention_project_frag_c512_w16_u4_bout`** | **101** | **0** | **0** | **16** | **8** | **36** | **0** | **0** | **0** | **32** | **32** | **0 (`-32`)** |
| `split_projection_frag_w16` | 99 | 1024 | 0 | 16 | 8 | 36 | 0 | 2 | 32 | 0 | 32 | 32 |
| **`split_projection_frag_w16_bskip`** | **99** | **1024** | **0** | **16** | **8** | **4** | **32** | **2** | **32** | **0** | **32** | **64** |
| `decoder_project2x_h16w_byteout_w` | 85 | 2176 | 0 | 95 | 0 | 40 | 0 | 5 | 0 | 0 | 208 | 128 |
| **`decoder_project2x_h16w_byteout_w_bin`** | **85** | **2176** | **0** | **80** | **20** | **0** | **0** | **5** | **0** | **0** | **208** | **288** |
| `mh_pool_project_group_c64_hin` | 102 | 2304 | 0 | 16 | 0 | 0 | 0 | 0 | 32 | 0 | 33 | 33 |
| **`mh_pool_project_group_c64_hin_out8`** | **99** | **2304** | **0** | **16** | **0** | **0** | **0** | **0** | **0** | **32** | **33** | **1 (`-32`)** |
| `mh_pool_project_group_c128_hin` | 147 | 4352 | 0 | 32 | 0 | 0 | 0 | 0 | 32 | 0 | 33 | 33 |
| **`mh_pool_project_group_c128_hin_out8`** | **147** | **4352** | **0** | **32** | **0** | **0** | **0** | **0** | **0** | **32** | **33** | **1 (`-32`)** |
| `mh_pool_project_group_c256` | 98 | 8448 | 0 | 8 | 0 | 4 | 0 | 0 | 32 | 0 | 33 | 33 |
| **`mh_pool_project_group_c256_out8`** | **98** | **8448** | **0** | **8** | **0** | **4** | **0** | **0** | **0** | **32** | **33** | **1 (`-32`)** |
| `mh_pool_project_group_c512` | 98 | 16640 | 0 | 8 | 0 | 4 | 0 | 0 | 32 | 0 | 33 | 33 |
| **`mh_pool_project_group_c512_out8`** | **98** | **16640** | **0** | **8** | **0** | **4** | **0** | **0** | **0** | **32** | **33** | **1 (`-32`)** |
| **`vit_gather_b8`** | **7** | **0** | **0** | **1** | **0** | **0** | **4** | **0** | **1** | **0** | **0** | **0** |

> [!IMPORTANT]
> In `c512_ffn_one_w2f8_w16_body`, replacing the 64B FP32 input load + `c5d_pack8f` with a 16B `ar8` load initially shrank the Stage-1 loop body enough for Clang's heuristic to fully unroll `for (uint gs = 0; gs < 16; gs++)` (`16x`), spiking `split_ffn_one_w2f8_w16_bin` to `256` VGPRs with `44` bytes of scratch spills. Adding `_Pragma("clang loop unroll_count(2)")` matched the stock `2x` unroll factor, restoring **`124` VGPRs, Occupancy 10, and `0` spills**, while cutting `global_load_b128` in the loop body from `16` to `8` + `4 global_load_b64` and eliminating all 64 dynamic `v_cvt_pk_fp8_f32` instructions per wave.

---

## 3. Full Frame Gold Gate (`1920x1152`, 3 Frames)

All 6 bitmask configurations (`NR_VIT_INTER_BYTE = 1, 3, 7, 9, 15, 31`) were verified on `amd9070` (`gfx1201`):

| Role | `NR_VIT_INTER_BYTE` | Active Extensions | `vit_inter_byte_calls` (3f) | First / Last SHA256 | `record_ok` / `accepted` | `pool_MiB` | `owned_MiB` |
|---|---:|---|---:|---|---|---:|---:|
| `baseline-m1` | `1` | ViT inter-block (`31..38`) | `21` (`7/f`) | `0900E489...0F4A` (`0 diff`) | `3 / 3` | `277.1 MiB` | `565.9 MiB` |
| `candidate-m3` | `3` (`1\|2`) | `+` Down C64/C128 byte edge | `27` (`9/f`) | `0900E489...0F4A` (`0 diff`) | `3 / 3` | `277.1 MiB` | `565.9 MiB` |
| `candidate-m7` | `7` (`1\|2\|4`) | `+` ViT Entry/Exit (`-1` launch) | `33` (`11/f`) | `0900E489...0F4A` (`0 diff`) | `3 / 3` | `277.1 MiB` | `565.9 MiB` |
| `candidate-m9` | `9` (`1\|8`) | ViT inter-block `+` C512 16-block byte stream | `69` (`23/f`) | `0900E489...0F4A` (`0 diff`) | `3 / 3` | **`276.0 MiB`** | **`564.9 MiB`** |
| **`candidate-m15`** | **`15` (`1\|2\|4\|8`)** | **All inter-block byte streams (Default)** | **`81` (`27/f`)** | **`0900E489...0F4A` (`0 diff`)** | **`3 / 3`** | **`276.0 MiB`** | **`564.9 MiB`** |
| `candidate-m31` | `31` (`1..16`) | `+` C512 intra-block FB8 (`nof32`) | `129` (`43/f`) | `0900E489...0F4A` (`0 diff`) | `3 / 3` | **`276.0 MiB`** | **`564.9 MiB`** |

---

## 4. 3-Round 4-Slot ABBA Benchmark (`240` Frames / Slot, Drop `80` Warmup = `160` Measured / Slot, `960` Frames / Arm)

### Arm 1: `NR_VIT_INTER_BYTE = 15` (Production Default) vs `NR_VIT_INTER_BYTE = 1` (Campaign 6 Baseline `e337af3d`)

| Round | `A1` Mean (Med) | `B1` Mean (Med) | `B2` Mean (Med) | `A2` Mean (Med) | Baseline `A` Mean (Med) | Candidate `B` Mean (Med) | $\Delta$ Mean (`B - A`) | $\Delta$ Median (`B - A`) |
|---|---|---|---|---|---|---|---|---|
| `r1` | `9.0426` (`9.0480`) | `9.0814` (`9.0690`) | **`8.9601` (`8.9445`)** | `9.0897` (`9.1005`) | `9.0662` (`9.0760`) | `9.0208` (`9.0110`) | **`-0.0454 ms`** | **`-0.0650 ms`** |
| `r2` | `9.0935` (`9.0885`) | `9.0766` (`9.0695`) | `9.0424` (`9.0350`) | `9.1129` (`9.1060`) | `9.1032` (`9.0960`) | `9.0595` (`9.0575`) | **`-0.0437 ms`** | **`-0.0385 ms`** |
| `r3` | `9.1240` (`9.1285`) | `9.0888` (`9.0775`) | `9.0803` (`9.0640`) | `9.1498` (`9.1545`) | `9.1369` (`9.1395`) | `9.0845` (`9.0710`) | **`-0.0524 ms`** | **`-0.0685 ms`** |
| **3-Round Pooled (`960f`)** | — | — | — | — | **`9.1021 ms` (`9.1010 ms`)** | **`9.0549 ms` (`9.0485 ms`)** | **`-0.0472 ms` (`-47.2 us`)** | **`-0.0525 ms` (`-52.5 us`)** |

- **3/3 rounds won**, p90 improved **`9.2160 -> 9.1830 ms` (`-0.0330 ms`)**, p99 improved **`9.3120 -> 9.2730 ms` (`-0.0390 ms`)**.
- **Breaks the `9.0 ms` barrier on single-slot steady state**: `r1/candidate-B2` achieved **`8.9601 ms` mean / `8.9445 ms` median** (160 steady-state frames)!

### Arm 2: `NR_VIT_INTER_BYTE = 31` (`+` C512 Intra-Block Transposed-WMMA FB8 `nof32`) vs `NR_VIT_INTER_BYTE = 1`

| Round | `A1` Mean (Med) | `B1` Mean (Med) | `B2` Mean (Med) | `A2` Mean (Med) | Baseline `A` Mean (Med) | Candidate `B` Mean (Med) | $\Delta$ Mean (`B - A`) | $\Delta$ Median (`B - A`) |
|---|---|---|---|---|---|---|---|---|
| `r1` | `9.0645` (`9.0600`) | `9.0278` (`9.0225`) | `9.0536` (`9.0395`) | `9.1017` (`9.1055`) | `9.0831` (`9.0825`) | `9.0407` (`9.0330`) | **`-0.0424 ms`** | **`-0.0495 ms`** |
| `r2` | `9.1305` (`9.1225`) | `9.0871` (`9.0875`) | `9.0928` (`9.0960`) | `9.1239` (`9.1260`) | `9.1272` (`9.1240`) | `9.0899` (`9.0930`) | **`-0.0373 ms`** | **`-0.0310 ms`** |
| `r3` | `9.1375` (`9.1540`) | `9.1181` (`9.1060`) | `9.1098` (`9.0985`) | `9.1567` (`9.1610`) | `9.1471` (`9.1565`) | `9.1140` (`9.1055`) | **`-0.0331 ms`** | **`-0.0510 ms`** |
| **3-Round Pooled (`960f`)** | — | — | — | — | **`9.1191 ms` (`9.1190 ms`)** | **`9.0815 ms` (`9.0770 ms`)** | **`-0.0376 ms` (`-37.6 us`)** | **`-0.0420 ms` (`-42.0 us`)** |

- `NR_VIT_INTER_BYTE = 31` also wins **3/3 rounds** (`-0.0376 ms` mean / `-0.0420 ms` median), but is `~0.010 ms` slower than `NR_VIT_INTER_BYTE = 15` (`-0.0472 ms` mean / `-0.0525 ms` median) because in transposed WMMA (`B^T * A^T`), adjacent lanes `rc = 0..15` index `16` tokens (`stride 512B` on `av8`) instead of `16` columns (`stride 16B` on `wb`). Therefore, `HIP_VIT_INTER_BYTE = 15` is enabled as the default, and Bit 4 (`16`) is retained as an opt-in diagnostic flag.
