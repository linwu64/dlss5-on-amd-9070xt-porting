# Full-Network Epilogue De-Branching & FP8 Clamp Cleanup (`isa-epilogue-clean-20261014`): Gold & 3-Round ABBA Verification (PASS)

Date: 2026-10-14  
Results directory: `Development/results/isa-epilogue-clean-20261014/`  
Device: AMD Radeon RX 9070 XT (`gfx1201`), Driver `32.0.22029.9039` (`amdhip64_7.dll` ROCm 7.0.2 CLR)

## 1. Mechanism & ISA Changes

Across the active `gfx1201` kernel suite, five epilogue / conversion sites generated unnecessary `v_movreld`/`v_movrels` dynamic register indexing, per-element scalar/vector conditional branches (`s_cbranch`), or redundant `-0.0f` canonicalization instructions (`v_max_num_f32` + `v_cmp` + `v_cndmask_b32`):

1. **`mh_attention_project_frag_c512_w16_u4` & `_w16` (`hip/multihead_fast_padded.hip`, 16 calls/frame)**:
   - Reordered the epilogue loop to outer `_Pragma("unroll") for(uint e=0;e<8;e++)` (1 bounds check `if(p<valid_tokens)` per `e`) and inner `_Pragma("unroll") for(uint n=0;n<4;n++)`, with `valid_tokens = (cropw && !sx && !sy && cropw==workw) ? croph*workw : tokens`, using branchless `fmed3f(hi+0.f, -448.f, 448.f)` + `cvt_pk_fp8_f32` + `cvt_f32_fp8`.
   - **ISA (`multihead-fast-padded-wave-packed.hsaco`)**: `v_movrels_b32` **`4 -> 0`**, `s_cbranch` **`58 -> 17`** (`-41` branch instructions), total instructions `1029 -> 952` (`u4`) and `950 -> 931` (`u2`), `0` spills, 4 sequential `global_store_b32` per `e`.

2. **`split_projection_frag_w16` & `split_projection_frag` (`hip/deep_fast.hip`, 16 calls/frame)**:
   - Replaced `F(VIT_FAST_H(acc[j][e]))` + second `cvt_pk_fp8_f32(v)` with a single `fmed3f(x + 0.f, -448.f, 448.f)` -> `b8 = cvt_pk_fp8_f32(xc)` -> `v = cvt_f32_fp8(b8, 0)`. Because IEEE-754 `-0.0f + 0.0f = +0.0f` under RNE, `+0.f` satisfies the `+0.0f` contract for both `±0.0f` without `bits(x)&0x7fffffff == 0` comparisons.
   - **ISA (`deep_fast-packed-fast.hsaco`)**: `split_projection_frag_w16` instructions **`799 -> 648` (`-151` instructions, `-18.9%`)**, `v_max_num_f32` **`31 -> 0`**, `v_cndmask_b32` **`32 -> 0`**, VGPR `100 -> 99`; `split_projection_frag` instructions **`837 -> 680` (`-157` instructions)**. In `vit-stream-fast.hsaco`, `split_projection_frag_w16` instructions **`904 -> 745` (`-159`)** and `split_projection_frag` **`936 -> 716` (`-220`)**.

3. **`c512_qkv_attention_compact_w16` (`hip/c512_qkv_attention_compact.inc`, 16 calls/frame)**:
   - Replaced `__builtin_fminf(__builtin_fmaxf(x, -448.f), 448.f)` in `c5c_fp8(float x)` with `__builtin_amdgcn_fmed3f(x, -448.f, 448.f)`.
   - **ISA (`c512-m32-mh.hsaco`)**: `v_max_num_f32` **`16 -> 8`**, VGPR unchanged at `187` (`0` spills).

4. **`swin_wave2_body` float-output epilogue (`hip/wave_owned_mh.inc`)**:
   - Replaced nested ternary `post==3 ? Hrtz(v) : post==0 ? F(Hrtz(v)) : F(v)` with branchless evaluation `h=Hrtz(v), hi=post==0?h:v, hc=fmed3f(hi+0.f,-448.f,448.f), f=cvt_f32_fp8(cvt_pk_fp8_f32(hc,0.f,0,false),0), out=post==3?h:f`.
   - **ISA (`c64-wave2-fast.hsaco`)**: `s_cbranch` **`35 -> 6` (`-29` branches)** and total instructions reduced by **`166..177` instructions** across `c64_wave2_bi`, `c128_wave2_bi`, and `c256_wave2_bi_w16`.

5. **`mh_pool_project_group_body` (`hip/multihead_fast_padded.hip`, Downsample Pool+Project)**:
   - Reordered epilogue loop from `for(j=0..3) for(e=0..7)` to outer `_Pragma("unroll") for(uint e=0;e<8;e++)` (1 `if(q<M)` check per `e`) and inner `_Pragma("unroll") for(uint j=0;j<4;j++)` with branchless `fmed3f(a+0.f, -448.f, 448.f)`.
   - **ISA (`multihead-fast-padded-wave-packed.hsaco`)**:
     - `mh_pool_project_group_c64`: instructions **`2397 -> 1000` (`-1397`, `-58.3%`)**, `s_cbranch` **`94 -> 22`**, VGPR `102 -> 99`.
     - `mh_pool_project_group_c128`: instructions **`2635 -> 1238` (`-1397`, `-53.0%`)**, `s_cbranch` **`94 -> 22`**.
     - `mh_pool_project_group_c256`: instructions **`2344 -> 948` (`-1396`, `-59.6%`)**, `s_cbranch` **`95 -> 23`**.
     - `mh_pool_project_group_c512`: instructions **`2406 -> 1012` (`-1394`, `-57.9%`)**, `s_cbranch` **`95 -> 23`**.

6. **`c32_wave1_finish_b8*` downsample f32 path (`hip/wave_owned_c32.inc`)**:
   - Replaced `F(Hrtz(Hrtz(top+bottom)*.25f))` with `fmed3f(dv+0.f, -448.f, 448.f)` + `cvt_pk_fp8_f32` + `cvt_f32_fp8`, cutting `41` instructions (`v_cndmask_b32` `16 -> 0`) in `c32_wave1_finish_b8_w16`.

## 2. Full-Frame Gold Verification (`PASS`)

Scope: `1920x1152` (`DLSS5_NETWORK_HEIGHT=1080`, `DLSS5_NETWORK_1080_ROWS=1152`), `DLSS5_FAST_NUMERIC=1`, `DLSS5_HIP_PDL=1`, `DLSS5_HIP_SUBMIT_PULSE=auto`, `DLSS5_MULTI_PASS=1`, `DLSS5_TEMPORAL_MODE=0`, 3 repeat frames per role (`frame-gold/`).

| Role | Modules | `out-first.f16` & `out.f16` SHA256 | `weights_count` | `weights_bytes` | `submit_pulse` |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `baseline` | Pre-cleanup (`vit-w16-20261014`) | `0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A` | `184` | `297,609,000` | `record_ok=3 accepted=3 reject_mask=0` |
| `candidate` | Epilogue-cleaned (`18` rebuilt modules) | `0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A` | `184` | `297,609,000` | `record_ok=3 accepted=3 reject_mask=0` |

## 3. 3-Round 4-Slot Interleaved ABBA Performance (`PASS`)

Protocol: `baseline-A1 -> candidate-B1 -> candidate-B2 -> baseline-A2`, `240` frames/slot, discard first `80` warmup frames, measure `160` steady frames (`320` steady frames/arm/round, `960` steady frames/arm across 3 rounds), single process per slot under `D:\DLSSNR-Lab\gpu.lock`.

| Round | Baseline Mean (`A1` / `A2`) | Candidate Mean (`B1` / `B2`) | $\Delta$ Mean (`B - A`) | $\Delta$ Median | $\Delta$ p90 | $\Delta$ p99 | Pairwise (`B1-A1` / `B2-A2`) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Round 1** | `9.3896 ms` (`9.3549` / `9.4243`) | `9.2412 ms` (`9.2388` / `9.2436`) | **`-0.1484 ms` (`-148.4 µs`)** | `-141.5 µs` | `-157.0 µs` | `-155.0 µs` | `-116.1 µs` / `-180.7 µs` |
| **Round 2** | `9.4233 ms` (`9.4044` / `9.4421`) | `9.2925 ms` (`9.2731` / `9.3119`) | **`-0.1308 ms` (`-130.8 µs`)** | `-132.5 µs` | `-147.0 µs` | `-84.0 µs` | `-131.3 µs` / `-130.2 µs` |
| **Round 3** | `9.4660 ms` (`9.4555` / `9.4765`) | `9.3067 ms` (`9.2966` / `9.3167`) | **`-0.1593 ms` (`-159.3 µs`)** | `-155.0 µs` | `-166.0 µs` | `-180.0 µs` | `-158.9 µs` / `-159.7 µs` |
| **3-Round Pooled (960f/arm)** | **`9.4263 ms`** (`med 9.4190 ms`) | **`9.2801 ms`** (`med 9.2755 ms`) | **`-0.1462 ms` (`-146.2 µs`)** | **`-143.5 µs`** | **`-156.0 µs`** | **`-146.0 µs`** | **6/6 pairs negative (`< 0`)** |
