# Second-Round ISA Pathology Audit & Cleanup (`isa-audit2-20261014`): Gold & 3-Round ABBA Verification (PASS)

Date: 2026-10-14  
Results directory: `Development/results/isa-audit2-20261014/`  
Device: AMD Radeon RX 9070 XT (`gfx1201`), Driver `32.0.22029.9039` (`amdhip64_7.dll` ROCm 7.0.2 CLR)

## 1. Mechanism & ISA Changes

We performed a systematic second-round ISA pathology audit across all 18 compiled `.hsaco` modules on top of `d5b72614` (`isa-epilogue-clean-20261014`), targeting redundant `v_max_num_f32` / `v_min_num_f32` NaN-canonicalizations, `v_cmp_neq_f32` + `v_cndmask_b32` signed-zero branches in `F(x)` and byte-FP8 helpers, `s_cbranch` code duplication in `c32_wave1_finish*`, and scalar `ds_load_u16` / `global_store_b32` operations in `c32_wave1_post*` and `c32_wave1_finish*`:

1. **`F(x)` & `vit_contract_F_byte(x)` (`hip/deep_fast.hip`)**:
   - Replaced `clampf(x, -448.f, 448.f)` + `(bits(x)&0x7fffffffu)==0 ? 0.f : y` in `F(x)` and `vit_contract_F_byte(x)` with `__builtin_amdgcn_fmed3f(x + 0.f, -448.f, 448.f)` + `cvt_pk_fp8_f32`, while preserving `clampf(a,lo,hi) = minf(maxf(a,lo),hi)` for `c512-m32-deep` where `HIP_FP8_CLAMP_FMED3=1` is already active and VOPD dual-issue (`v_dual_mov_b32` / `v_dual_mul_f32`) depends on the DAG structure of `vit_expand_blocked_fp8_frag_bytein_w16` (`400` instructions unchanged).
   - **ISA (`vit-stream-fast.hsaco` & `c512-m32-deep.hsaco`)**:
     - `vit_stream_contract_frag_bout_compactw_w16`: **`581 -> 472` (`-109` instructions, `-18.8%`)**, `v_max_num_f32` **`23 -> 0`**, `v_cndmask_b32` **`28 -> 0`**.
     - `vit_stream_project_n64_bb_compactw_w16`: **`689 -> 595` (`-94` instructions, `-13.6%`)**, `v_max_num_f32` **`27 -> 0`**, `v_cndmask_b32` **`29 -> 0`**.
     - `vit_stream_qkv_frag_bin_w5f8`: **`575 -> 521` (`-54` instructions)**, `v_max_num_f32` `25 -> 9`, `v_cndmask_b32` `30 -> 16`.
     - `vit_stream_qkv_frag_hin_w5f8`: **`711 -> 665` (`-46` instructions)**, `v_max_num_f32` `23 -> 11`, `v_cndmask_b32` `29 -> 16`.
     - `split_ffn_fused_fp8_t8` (`c512-m32-deep`): **`692 -> 669` (`-23` instructions)**, `v_cndmask_b32` **`8 -> 0`**, `v_max_num_f32` `24 -> 16`.
     - `decoder_project2x_h16w_byteout` (`c512-m32-deep`): **`5618 -> 5425` (`-193` instructions)**, `v_max_num_f32` **`34 -> 0`**, `v_cndmask_b32` `87 -> 39`.

2. **`c32_wave1_finish*` Store-Predication & Vectorized `down` (`hip/wave_owned_c32.inc`)**:
   - Unified the `CW_FINISH_TAIL_VEC && !Crop && ByteOut && !ByteDown` path in `c32_wave1_finish*` so `Crop=true` (`c32_wave1_finish_dcrop_b8_w16`) also uses the `ds_load_b128` + `global_store_b128` vectorized `down` path instead of falling back to `134` scalar `ds_load_u16` and `31` scalar `global_store_b32` instructions, and hoisted the `t0` / `t1` computation out of the `if(!Crop)` / `else` branch so only the `global_store_b128` is predicated on `ox < cropw && oy < croph`. Also replaced `cw_up_F` with `__builtin_amdgcn_fmed3f(x + 0.f, -448.f, 448.f)`.
   - **ISA (`c32-wave1-fast.hsaco`)**:
     - `c32_wave1_finish_b8_w16`: **`2116 -> 1589` (`-527` instructions, `-24.9%`)**, `s_cbranch` **`25 -> 16`**, `ds_load_u16` **`64 -> 0`**, `global_store_b32` **`16 -> 0`** (`global_store_b128` `0 -> 4`).
     - `c32_wave1_finish_dcrop_b8_w16`: **`2557 -> 1621` (`-936` instructions, `-36.6%`)**, `s_cbranch` **`37 -> 18`**, `v_cndmask_b32` **`38 -> 0`**, `ds_load_u16` **`134 -> 0`**, `global_store_b32` **`31 -> 0`** (`ds_load_b128` `2 -> 18`, `global_store_b128` `0 -> 4`).
     - `c32_wave1_finish_dcrop_b8d_w16`: **`2203 -> 1591` (`-612` instructions, `-27.8%`)**, `s_cbranch` **`28 -> 18`**, `ds_load_b128` **`34 -> 18`**.

3. **`c32_wave1_post*` Vectorized `ds_load_b128` (`hip/wave_owned_c32.inc`)**:
   - Replaced the `8` scalar `ds_load_u16` (`sh_u16[l*8+e]`) in the `CW_POST_TAIL_VEC && ByteOut && W16` epilogue of `c32_wave1_post_b8_w16` and `c32_wave1_post_b8_logit_w16` with a single 16-byte `ds_load_b128` (`reinterpret_cast<const u4*>(sh_u16)[l]`) unpacked in registers.
   - **ISA (`c32-wave1-fast.hsaco`)**:
     - `c32_wave1_post_b8_w16`: **`1545 -> 1532` (`-13` instructions)**, `ds_load_u16` **`8 -> 0`**, `ds_load_b128` `5 -> 6`, `s_wait_dscnt` **`14 -> 7`**.
     - `c32_wave1_post_b8_logit_w16`: **`1664 -> 1658` (`-6` instructions)**, `ds_load_u16` **`8 -> 0`**, `ds_load_b128` `5 -> 6`, `s_wait_dscnt` **`14 -> 7`**.

4. **`c64_wave2_up_lb_sh` (`hip/wave_owned_mh.inc`) & C512 Helpers (`hip/multihead_fast_padded.hip`, `hip/c512_qkv_attention_fused.inc`)**:
   - Replaced `w2_z`, `w2_up_F`, and `w2_skip_byte` in `hip/wave_owned_mh.inc` with `__builtin_amdgcn_fmed3f(x + 0.f, -448.f, 448.f)` + `cvt_pk_fp8_f32`, cutting `c64_wave2_up_lb_sh` (`c64-wave2-fast.hsaco`) from **`4770 -> 4541` (`-229` instructions)** and `v_cndmask_b32` from **`175 -> 47` (`-128`)**.
   - Replaced `F` / `mh_fp8_pack2` / `c5f_z` / `c5f_fp8` in `hip/multihead_fast_padded.hip` and `hip/c512_qkv_attention_fused.inc` with `__builtin_amdgcn_fmed3f`, cutting `c512_qkv_attention_fused` (`1759 -> 1614`, `-145` insts) and `mh_qkv_normalize_frag_c512_m32` (`803 -> 745`, `-58` insts).

5. **Diagnostic Finding — Uniform-SGPR `m0` `v_movrel` vs `v_cndmask_b32` Selection Trees (`wave_owned_c32.inc` & `wave_owned_mh.inc`)**:
   - We explicitly tested replacing the `qt = 0..3` array indexing in `c32_wave1_chain_w16` (`12 v_movreld_b32` + `4 v_movrels_b32`) and `wave_owned_mh.inc` (`4 v_movrels_b32`) with branchless ternary selection trees (`(qt&2)?((qt&1)?w3:w2):((qt&1)?w1:w0)`).
   - Because `qt` is a **uniform loop counter in an SGPR**, `m0`-relative VGPR indexing (`s_lshl_b32 m0, s_qt, 2` + `v_movrels_b32` / `v_movreld_b32`) executes in **1 VALU instruction per word** and keeps the 16-register array contiguous without extending per-element live ranges. Replacing it with ternary selection emitted `56` `v_cndmask_b32_e64` instructions in `c32_wave1_chain_w16` (`1003 -> 1111` insts, `+108` insts × 22 dispatches/frame) and broke VOPD dual-issue pairing in `c128_wave2_bi_bo` (`+54` insts) and `sp_run256_w16` (`+61` insts), regressing end-to-end frame time by `+0.14 ms`. Reverting the `v_movrel` ternary trees restored `c32_wave1_chain_w16` (`1003`), `c128_wave2_bi_bo` (`3591`), and `sp_run256_w16` (`5195`) to zero regression while preserving all epilogue and `fmed3f` reductions.

## 2. Full-Frame Gold Verification (`PASS`)

Scope: `1920x1152` (`DLSS5_NETWORK_HEIGHT=1080`, `DLSS5_NETWORK_1080_ROWS=1152`), `DLSS5_FAST_NUMERIC=1`, `DLSS5_HIP_PDL=1`, `DLSS5_HIP_SUBMIT_PULSE=auto`, `DLSS5_MULTI_PASS=1`, `DLSS5_TEMPORAL_MODE=0`, 3 repeat frames per role (`frame-gold/`).

| Role | Modules | `out-first.f16` & `out.f16` SHA256 | `weights_count` | `weights_bytes` | `submit_pulse` |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `baseline` | `d5b72614` (`isa-epilogue-clean-20261014`) | `0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A` | `184` | `297,609,000` | `record_ok=3 accepted=3 reject_mask=0` |
| `candidate` | `isa-audit2-20261014` (`18` rebuilt modules) | `0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A` | `184` | `297,609,000` | `record_ok=3 accepted=3 reject_mask=0` |

## 3. 3-Round 4-Slot Interleaved ABBA Performance (`PASS`)

Protocol: `baseline-A1 -> candidate-B1 -> candidate-B2 -> baseline-A2`, `240` frames/slot, discard first `80` warmup frames, measure `160` steady frames (`320` steady frames/arm/round, `960` steady frames/arm across 3 rounds), single process per slot under `D:\DLSSNR-Lab\gpu.lock`.

| Round | Baseline Mean (`A1` / `A2`) | Candidate Mean (`B1` / `B2`) | $\Delta$ Mean (`B - A`) | $\Delta$ Median | $\Delta$ p90 | $\Delta$ p99 | Pairwise (`B1-A1` / `B2-A2`) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Round 1** | `9.2840 ms` (`9.2777` / `9.2903`) | `9.2835 ms` (`9.2769` / `9.2901`) | **`-0.0005 ms` (`-0.5 µs`)** | `+3.0 µs` | `-21.0 µs` | `-11.0 µs` | `-0.8 µs` / `-0.2 µs` |
| **Round 2** | `9.2691 ms` (`9.2528` / `9.2854`) | `9.2706 ms` (`9.2627` / `9.2786`) | **`+0.0015 ms` (`+1.5 µs`)** | `-6.5 µs` | `+11.0 µs` | `+29.0 µs` | `+9.9 µs` / `-6.8 µs` |
| **Round 3** | `9.3152 ms` (`9.3136` / `9.3168`) | `9.2973 ms` (`9.3135` / `9.2811`) | **`-0.0179 ms` (`-17.9 µs`)** | `-21.5 µs` | `-2.0 µs` | `-7.0 µs` | `-0.1 µs` / `-35.8 µs` |
| **3-Round Pooled (960f/arm)** | **`9.2894 ms`** (`med 9.2860 ms`) | **`9.2838 ms`** (`med 9.2765 ms`) | **`-0.0056 ms` (`-5.6 µs`)** | **`-9.5 µs`** | **`-7.0 µs`** | **`+0.0 µs`** | **5/6 pairs negative (`< 0`)** |
