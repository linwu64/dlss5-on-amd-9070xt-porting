# ViT Inter-Block Byte Stream (`blocks 31..37 -> 32..38`) + QKV Normalization Epilogue Hoist (`vit-inter-byte-20261014`)

## 1. Discovery & Structural Audit vs. Mochizuki (`mz`)

We performed a systematic cross-stage structural and ISA audit comparing our 161-dispatch production graph (`vit-w16-20261014`) against Mochizuki's RDNA4 shader pipeline (`nr_graph.cpp`, `vit_attn.comp`, `gemm1x1.comp`, `attn.comp`, `ffwd3_t.comp`) and our historical failure ledger (`Development/failed-experiments.md`):

1. **Gap C — ViT Inter-Block Boundary (`blocks 31..38`, 8 blocks)**:
   - **Mochizuki's ViT block structure (`5` launches/block = `40` launches total)**:
     - At the end of blocks `31..37`, `gemmproj` writes **1-byte E4M3** directly (`640 × 1024 × 1B = 0.64 MB`).
     - The next block (`32..38`) reads that 1-byte E4M3 directly in `gemmvact` (Expand) and as the `skip` residual in `gemmproj` (Contract).
   - **Our `vit-w16-20261014` production pipeline (`vit_stream=3`, `vit_contract_byte_edge=1`, `HIP_VIT_W16=7`) had `6` launches/block (`48` launches total)**:
     1. At the end of block $b \in \{31..37\}$, `vit_stream_project_n64_bb_compactw_w16` computed `F(VIT_FAST_H(total))`, which converted FP32 to E4M3 (`v_cvt_pk_fp8_f32`), converted **back to FP32** (`v_cvt_f32_fp8_e32`), and wrote **`2.56 MB` of FP32** (`640 × 1024 × 4B`) to DRAM (`out`).
     2. At the start of block $b+1 \in \{32..38\}$, the host launched a separate **`vit_pack_input`** kernel (`7` inter-block launches/frame) that read back the **`2.56 MB` of FP32** (`input`) and re-quantized it to **`0.64 MB` of E4M3** (`expanded_input`).
     3. Block $b+1$'s `vit_stream_contract_frag_bout_compactw_w16` then read the **`2.56 MB` of FP32** (`input`) from DRAM as its `skip` residual!
   - **Why the legacy `opt.vit_byte_stream` was never enabled in production**:
     - The legacy `opt.vit_byte_stream` branch (`hip_reference_network.h:871`) used pre-`vit_stream` non-compact, non-W16 kernels (`vit_project_bytein_bout` writing **both** `2.56 MB` FP32 `out` AND `0.64 MB` FP8 `out8`, plus non-W16 `vit_contract_blocked_fp8_bstream` and 1-wave `vit_qkv_project_normalize_fused_f16compact_fp8_bytein`).
   - **Why Inter-Block Byte Stream on the Modern Compact-W16 Pipeline (`HIP_VIT_INTER_BYTE=1`) is 100% Bit-Exact**:
     - Every element produced by block $b$'s projection is `F(VIT_FAST_H(total))`, which is already on the exact E4M3 lattice (`+0.0f` canonicalized by `x + 0.f`, saturated to `[-448, 448]`).
     - Writing `byte_F(VIT_FAST_H(total))` stores the exact E4M3 byte (`0.64 MB` instead of `2.56 MB`).
     - In block $b+1$, `expanded_input` is already that exact `0.64 MB` E4M3 tensor (`vit_pack_input` is completely eliminated for blocks `32..38`), and `vit_stream_contract_frag_bstream_bout_compactw_w16` decodes `skip` via `__builtin_amdgcn_cvt_f32_fp8(byte, 0)`, yielding the **exact same IEEE-754 FP32 bits** as `F(VIT_FAST_H(total))`!
     - Block `38` still runs `vit_stream_project_n64_bb_compactw_w16` (writing FP32 `out` for `Gather(..., true)` -> `decoder39`).
   - **Per-Frame Savings**:
     - Eliminates **`7` kernel launches per frame** (`vit_pack_input` drops from `8 -> 1` call/frame; total full-network dispatches drop from **`161 -> 154`**).
     - Eliminates **`49.28 MB` of global memory traffic per frame** across the 7 inter-block boundaries:
       $$7 \times \bigl(\underbrace{1.92\text{ MB}}_{\text{proj write } 2.56 \to 0.64} + \underbrace{2.56\text{ MB}}_{\text{pack read}} + \underbrace{0.64\text{ MB}}_{\text{pack write}} + \underbrace{1.92\text{ MB}}_{\text{contract skip read } 2.56 \to 0.64}\bigr) = 49.28\text{ MB/frame}.$$

2. **`HIP_BYTE_F_ADD0 1` + Normalization Epilogue Hoist in `vit-stream` / `vit-stream-fast` (`hip/build-modules.ps1`, `hip/vit_stream.inc`)**:
   - **Double FP8 conversion in `byte_F` (`HIP_BYTE_F_ADD0` missing in `vit-stream` / `vit-stream-fast`)**:
     - Unlike `deep_fast-packed-fast` and `c512-m32-deep`, `vit-stream` and `vit-stream-fast` lacked `HIP_BYTE_F_ADD0 1`, causing `byte_F(v)` to call `cvt_pk_fp8_f32(F(v))` (`float -> fp8 -> float -> fp8` **twice** per output byte: `16` redundant `v_cvt_f32_fp8_e32` + `16` redundant `v_cvt_pk_fp8_f32` + `16` `v_mov_b32 0` per wave).
     - Adding `HIP_BYTE_F_ADD0 1` to `vit-stream` and `vit-stream-fast` (already proven bit-exact across all $2^{32}$ floats in `f-sweep-20260930`) removes `32` `v_cvt` instructions per wave in `vit_stream_qkv_frag_bin_w5f8` (`cvt: 48 -> 16`) and `vit_stream_project_n64_bb_bout_compactw_w16` (`cvt: 96 -> 64`).
   - **Normalization epilogue hoist in `vit_stream_qkv_frag_bin_w5f8` (`hip/vit_stream.inc:258-266`)**:
     - Previously, `if (part < 2)` was inside the `for (j=0..1) for (e=0..7)` store loop, and `maxf(sum[e], 6.198883056640625e-5f)` used `a > b ? a : b` (emitting `v_max_num_f32 vX, vX, vX` sNaN quietening before `v_max_num_f32`). Worse, Clang predicated the normalization with `16` `v_cndmask_b32` and executed all `8` `v_rsq_f32` and `16` `v_mul_f32` **even when `part == 2` (the V projection, 1/3 of all threadblocks)**!
     - Hoisting `if (part < 2)` before the store loop and using `__builtin_fmaxf`:
       ```cpp
       if(part<2){
        const float scale=part==0?5.65625f*w[786432+row/32]:1.f;
        #pragma unroll
        for(uint e=0;e<8;e++){float inv=__builtin_amdgcn_rsqf(__builtin_fmaxf(sum[e],6.198883056640625e-5f))*scale;acc[0][e]*=inv;acc[1][e]*=inv;}
       }
       #pragma unroll
       for(uint j=0;j<2;j++)for(uint e=0;e<8;e++)out[(part*tokens+first+gr()*8+e)*1024+row+j*16+rc()]=byte_F(acc[j][e]);
       ```
       skips the scale load, all `8` `v_rsq_f32`, and all `16` `v_mul_f32` for `part == 2` via a scalar branch (`s_cbranch_scc0`), and cuts total VALU instructions in `vit_stream_qkv_frag_bin_w5f8` from **`233 -> 168` (`-65` VALU, `-28%`)**!

## 2. ISA & Resource Comparison (`gfx1201`)

| Kernel | Total Instrs | WMMA | VALU | `v_cvt` | Global Loads | Global Stores | VGPRs | SGPRs | Scratch |
|---|---|---|---|---|---|---|---|---|---|
| `vit_stream_qkv_frag_bin_w5f8` (baseline) | `533` | `18` | `233` | `48` | `18` | `16` (`b8`) | `114` | `32` | `0 B` |
| `vit_stream_qkv_frag_bin_w5f8` (**candidate**) | **`501` (`-32`)** | `18` | **`168` (`-65`)** | **`16` (`-32`)** | `18` | `16` (`b8`) | **`114`** | `32` | `0 B` |
| `vit_stream_contract_frag_bout_compactw_w16` (block 31) | `516` | `16` | `230` | `32` | `52` (`32×b32` skip) | `33` (`32×b8`) | `115` | `14` | `0 B` |
| `vit_stream_contract_frag_bstream_bout_compactw_w16` (**blocks 32..38**) | **`517`** | `16` | `240` | `64` | **`52` (`32×u8` skip)** | `33` (`32×b8`) | **`115`** | `14` | `0 B` |
| `vit_stream_project_n64_bb_compactw_w16` (block 38) | `531` | `16` | `269` | `96` | `52` | `32` (`32×b32` = 128B/lane) | `114` | `12` | `0 B` |
| `vit_stream_project_n64_bb_bout_compactw_w16` (**blocks 31..37**) | **`536`** | `16` | **`226` (`-43`)** | **`64` (`-32`)** | `52` | **`32` (`32×b8` = 32B/lane)** | **`114`** | `12` | `0 B` |

## 3. Gold Gate Verification (`1080p` / `1920×1152`, 3 Frames)

All three roles (`baseline` with `vit-w16-20261014` modules + `NR_VIT_INTER_BYTE=0`, `candidate-qkv-only` with new `vit-stream-fast.hsaco` + `NR_VIT_INTER_BYTE=0`, and `candidate-inter-byte` with new `vit-stream-fast.hsaco` + `NR_VIT_INTER_BYTE=1`) passed the 3-frame Gold Gate with bit-identical outputs:
- `out-first.f16` & `out.f16` SHA256: `0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A`
- `submit_pulse`: `record_ok=3 accepted=3 reject_mask=0 lifetime_pdl_calls=0`
- `C512_W16_SUMMARY`: `vit_inter_byte=1 vit_inter_byte_calls=21` (`7` inter-block byte transitions/frame × `3` frames)
- **Zero extra VRAM (`0 B`)**: `weights_MiB=283.8 (184) pool_MiB=277.1 (27 tensors) gather_maps_MiB=5.0 noise_MiB=0.0 owned_MiB=565.9` — identical between `baseline` and `candidate-inter-byte`.

## 4. 3-Round 4-Slot ABBA Results (`240` Frames / Slot, Drop `80` Warmup = `160` Measured / Slot, `960` Frames / Arm)

### `NR_VIT_INTER_BYTE=1` + `vit-stream-fast.hsaco` (`B`) vs `vit-w16-20261014` Baseline (`A`)

| Round | `A1` Mean (`med`) | `B1` Mean (`med`) | `B2` Mean (`med`) | `A2` Mean (`med`) | Baseline Mean (`A`) | Candidate Mean (`B`) | $\Delta$ Mean (`B - A`) | $\Delta$ Median (`B - A`) |
|---|---|---|---|---|---|---|---|---|
| `r1` | `9.2172` (`9.2140`) | `9.0424` (`9.0372`) | `9.0815` (`9.0805`) | `9.2659` (`9.2670`) | `9.2416 ms` | `9.0620 ms` | **`-0.1796 ms`** | **`-0.1816 ms`** |
| `r2` | `9.2776` (`9.2651`) | `9.1218` (`9.1358`) | `9.1232` (`9.1247`) | `9.3164` (`9.3114`) | `9.2970 ms` | `9.1225 ms` | **`-0.1745 ms`** | **`-0.1580 ms`** |
| `r3` | `9.3033` (`9.2920`) | `9.1415` (`9.1475`) | `9.1516` (`9.1488`) | `9.3039` (`9.2917`) | `9.3036 ms` | `9.1466 ms` | **`-0.1571 ms`** | **`-0.1437 ms`** |
| **3-Round Aggregate** | — | — | — | — | **`9.2807 ms`** | **`9.1103 ms`** | **`-0.1704 ms` (`-1.84%`)** | **`-0.1611 ms`** |

- Every single `B` slot (`9.0424..9.1516 ms` mean, `9.0372..9.1488 ms` median) beat every single `A` slot (`9.2172..9.3164 ms` mean, `9.2140..9.3114 ms` median) across all 3 rounds (`3/3` rounds, `6/6` slots) with zero overlap!
- Single-slot median reached **`9.0372 ms`** (`r1/candidate-B1`), with `p90 = 9.1472 ms` and `p99 = 9.1959 ms`.

## 5. Verdict

- **`HIP_VIT_INTER_BYTE=1` + `vit-stream-fast.hsaco` (`HIP_BYTE_F_ADD0 1` + QKV epilogue hoist) is promoted to production default.**
- Total full-network dispatches drop from **`161 -> 154` (`-7` launches/frame)**, ViT inter-block DRAM traffic drops by **`-49.28 MB/frame`**, VRAM usage is completely unchanged (`owned_MiB = 565.9`, `0` extra bytes), and 1080p full-frame wall time improves by **`-0.1704 ms` mean / `-0.1611 ms` median (`-1.84%`)** down to **`9.1103 ms` 3-round aggregate mean (`9.0372 ms` best slot median)**.
