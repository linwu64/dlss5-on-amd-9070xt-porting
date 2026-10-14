# ViT Core Wide Fragment Weight Loads + Outer-Part Loop Unroll Control (`vit-w16-20261014`)

## 1. Discovery & Root-Cause Audit

We conducted a systematic ISA and register/occupancy audit across Targets 3A (`c64_wave2`, `c128_wave2`) and 3B (`c512_qkv_attention_compact_w16` and ViT core kernels across blocks `31..38`):

1. **Target 3A (`c64_wave2`, `c128_wave2` in `c64-wave2-fast.hsaco`)**:
   - Already runs with `W2_QKV_FUSE=3`, `W2_FFN_QT_BATCH=4`, `W2_UP_LOW_BYTES=1`, `W2_DOWN_HALF=1`, and `W2_UP_VEC=1`.
   - `W2_FFN_W16_SMALL` (`FragmentPackedMatrixW16` for C64/C128 FFN) was already tested in `w16-c64-c128-20260930` (`failed-experiments.md:2022`) and `bitexact-pm-20261001` (`failed-experiments.md:2140`), and falsified as flat (`-0.001..-0.007 ms` noise) because C64 (`K=256`, `64 KB`) and C128 (`K=512`, `256 KB`) FFN weights fit comfortably inside L2/MALL and are hidden by multi-wave workgroup barriers (`128` threads / 4 waves).

2. **Target 3B (`c512_qkv_attention_compact_w16` in `c512-m32-deep-fast.hsaco`)**:
   - Uses `187` VGPRs (`D=4`) and `6144 B` LDS per 2-wave workgroup (`3072 B` LDS/wave).
   - On RDNA4 (`gfx1201`), `161..192` VGPRs all map to `8 waves/SIMD`, while `3072 B` LDS/wave already caps hardware residency at `5 waves/SIMD` (`20 waves/CU`). Recompiling with `D=3, 2, 1` yields `183, 179, 171` VGPRs — remaining in the exact same VGPR tier (`8 waves/SIMD`) and LDS cap (`5 waves/SIMD`) while reducing prefetch depth.

3. **Target 3B (ViT Core Kernels in `deep_fast-packed-fast.hsaco` & `vit-stream-fast.hsaco`, 8 blocks `31..38`)**:
   - **`vit_stream_qkv_frag_bin_w5f8`** (`0.331 ms`, 8 calls/frame): Already uses 16B `vit_frag_matrix_w16` (`40` `global_load_b128`, `0` `global_load_b64`, `114` VGPRs = `10 waves/SIMD`, `0` scratch).
   - **`vit_attention_fused_640_bytein_bout`** (`0.307 ms`, 8 calls/frame): Pure token-to-token QK/PV WMMA + online softmax (`162` VGPRs = `8 waves/SIMD`, `39,936 B` LDS/WG = 1 WG/CU by design, `0` `global_load_b64`).
   - **`vit_expand_blocked_fp8_frag_bytein`** (`0.223 ms`, 24 calls/frame = 3× per ViT block): Still used 8B `FragmentPackedMatrix` (`128` `global_load_b64` instructions per wave, `77` VGPRs, `25` SGPRs).
   - **`vit_stream_contract_frag_bout_compactw`** (`0.343 ms`, 8 calls/frame) & **`vit_stream_project_n64_bb_compactw`** (1 call/frame):
     - Both still used 8B `FragmentPackedMatrix` (`256` and `128` `global_load_b64` instructions per wave) and suffered severe VGPR bloat (**`211` VGPRs** and **`190` VGPRs** = **`6 waves/SIMD` occupancy cliff**!).
     - Why did an earlier ViT W16 attempt (`failed-experiments.md:2657`) regress by `+0.032 ms`? Because Clang completely unrolled the outer `for (uint part = 0; part < 4u; ++part)` loop in `vit_contract_blocked_body` and `for (uint p = 0; p < 4u; ++p)` in `vit_stream_project_tiles`, exploding VGPR usage to `251` and `220` VGPRs (`6 waves/SIMD`)!

## 2. Design & Implementation (`HIP_VIT_W16=7`)

1. **In-Place Host `FragmentPackedMatrixW16` (`Development/HIP/hip_reference_network.h`)**:
   - Controlled by `HIP_VIT_W16` (default `7`; runtime bitmask override via `NR_VIT_W16` / `DLSS5_HIP_VIT_W16`: bit `1` = Expand, bit `2` = Contract, bit `4` = Projection):
     - `PackedVitWeight`: packs `[rows, 640]` ViT Expand FP8 weights in-place via `FragmentPackedMatrixW16(out, 0, rows, cols)` under `@vit-frag@compact-expand`.
     - `CompactContractWeight`: packs `[640, 2560]` ViT Contract FP8 weights in-place via `FragmentPackedMatrixW16(out, 0, 640, 2560)` under `@vit-frag@compact-contract`.
     - `CompactProjectionWeight`: packs `[512, 640]` ViT Final Projection FP8 weights in-place via `FragmentPackedMatrixW16(out, 0, 512, 640)` under `@vit-proj-frag@compact-projection`.
   - **Zero extra VRAM (`0 B`)**: All three pack in-place inside existing weight buffers (`weights_count = 184`, `weights_bytes = 297,609,000 B`).

2. **Device Kernels + Outer-Part Unroll Control (`hip/deep_fast.hip`, `hip/vit_stream.inc`)**:
   - **`vit_expand_blocked_fp8_frag_bytein_w16`**: Uses `vit_weight_fragment_native_w16` (`global_load_b128` per 32-K pair `k+=32`) across `k = 0..640`, replacing `128` `global_load_b64` with `64` wave-coalesced `global_load_b128` (`77` VGPRs, SGPRs drop `25 -> 13`).
   - **`vit_stream_contract_frag_bout_compactw_w16`**: Adds `_Pragma("clang loop unroll(disable)")` on the outer `for (uint part = 0; part < 4u; ++part)` loop and `_Pragma("unroll 2")` on the inner `k += 32u` W16 loop. Each `part` still executes `20` W16 steps (`40` WMMA tiles, `128` `global_load_b128` total vs `256` `global_load_b64`), while cutting VGPRs by **`-96` (`211 -> 115` VGPRs)** and lifting occupancy from **6 to 8 waves/SIMD**!
   - **`vit_stream_project_n64_bb_compactw_w16`**: Hoists the `p == 0` skip-connection load before `_Pragma("clang loop unroll(disable)") for (uint p = 0; p < 4u; ++p)` with `_Pragma("unroll 2")` on `k += 32u`, cutting weight loads from `128` `global_load_b64` to `64` `global_load_b128`, cutting VGPRs by **`-76` (`190 -> 114` VGPRs)**, and lifting occupancy from **6 to 10 waves/SIMD**!

3. **ISA Comparison (`gfx1201`)**:

| Kernel | VGPRs | SGPRs | LDS | Scratch | `global_load_b64` | `global_load_b128` (Weights) | Occupancy (`gfx1201`) |
|---|---|---|---|---|---|---|---|
| `vit_expand_blocked_fp8_frag_bytein` (stock) | `77` | `25` | `0 B` | `0 B` | `128` | `0` | `16` waves/SIMD |
| `vit_expand_blocked_fp8_frag_bytein_w16` | **`77`** | **`13` (`-12`)** | `0 B` | `0 B` | **`0`** | **`64`** | **`16` waves/SIMD** |
| `vit_stream_contract_frag_bout_compactw` (stock) | `211` | `14` | `4096 B` | `0 B` | `256` | `0` | `6` waves/SIMD (VGPR-bound) |
| `vit_stream_contract_frag_bout_compactw_w16` | **`115` (`-96`)** | `14` | `4096 B` | `0 B` | **`0`** | **`128`** | **`8` waves/SIMD (LDS-bound)** |
| `vit_stream_project_n64_bb_compactw` (stock) | `190` | `12` | `0 B` | `0 B` | `128` | `0` | `6` waves/SIMD (VGPR-bound) |
| `vit_stream_project_n64_bb_compactw_w16` | **`114` (`-76`)** | `12` | `0 B` | `0 B` | **`0`** | **`64`** | **`10` waves/SIMD (`+67%`)** |

## 3. Gold Gate Verification (`1080p` / `1920×1152`, 3 Frames)

All four modes (`NR_VIT_W16=0` baseline, `NR_VIT_W16=1` expand-only, `NR_VIT_W16=6` contract+proj, `NR_VIT_W16=7` all three, on top of `NR_C512_W16=2`, `NR_C512_FFN_W16=1`, `NR_C32_W16=1`) produced bit-identical outputs (`out-first.f16` and `out.f16` SHA256 = `0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A`), `record_ok=3`, `accepted=3`, `reject_mask=0`, and `extra_vram_bytes = 0` (`weights_count=184`, `weights_bytes=297609000`).

## 4. 3-Round 4-Slot ABBA Results (`240` Frames / Slot, Drop `80` Warmup = `160` Measured / Slot, `960` Frames / Arm)

### `NR_VIT_W16=7` (`vit_expand_w16` + `vit_contract_w16` + `vit_project_w16`) vs `NR_VIT_W16=0` (Stock ViT, with `NR_C512_W16=2`, `NR_C512_FFN_W16=1`, `NR_C32_W16=1` active on both)

| Round | `A1` Mean (`med`) | `B1` Mean (`med`) | `B2` Mean (`med`) | `A2` Mean (`med`) | Baseline Mean (`A`) | Candidate Mean (`B`) | $\Delta$ Mean (`B - A`) | $\Delta$ Median (`B - A`) |
|---|---|---|---|---|---|---|---|---|
| `r1` | `9.4041` (`9.4020`) | `9.3777` (`9.3620`) | `9.3914` (`9.3770`) | `9.4605` (`9.4670`) | `9.4323 ms` | `9.3846 ms` | **`-0.0478 ms`** | **`-0.0650 ms`** |
| `r2` | `9.4574` (`9.4590`) | `9.4220` (`9.4190`) | `9.4167` (`9.4020`) | `9.5000` (`9.4990`) | `9.4787 ms` | `9.4194 ms` | **`-0.0593 ms`** | **`-0.0685 ms`** |
| `r3` | `9.5035` (`9.5030`) | `9.4560` (`9.4490`) | `9.4356` (`9.4170`) | `9.5139` (`9.4950`) | `9.5087 ms` | `9.4458 ms` | **`-0.0629 ms`** | **`-0.0660 ms`** |
| **3-Round Aggregate** | — | — | — | — | **`9.4732 ms`** | **`9.4166 ms`** | **`-0.0566 ms` (`-0.60%`)** | **`-0.0665 ms`** |

## 5. Verdict

- **`HIP_VIT_W16=7` is promoted as default**, winning **3/3 ABBA rounds** with **`-0.0566 ms` mean / `-0.0665 ms` median** (`9.4732 ms -> 9.4166 ms` mean, `9.4708 ms -> 9.4043 ms` median, single-slot median down to **`9.3620 ms`**), `0` extra VRAM, and bit-exact 3-frame Gold (`0900E489...`).
- Combined across all three W16 campaigns today (`c512-ffn-w16-20261014` `-0.1312 ms` + `c32-w16-20261014` `-0.0240 ms` + `vit-w16-20261014` `-0.0566 ms`), 1080p full-frame wall time has dropped by **`-0.2118 ms` mean / `-0.2338 ms` median** (`9.5926 ms -> 9.4166 ms` mean, single-slot median `9.3620 ms`).
