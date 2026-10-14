# C512 Split-FFN Wide Fragment Loads (`c512-ffn-w16-20261014`)

## 1. Discovery & Motivation

In `c512-w16-20261014` (`DevHistory.md:471`), the 3 other C512 kernels (`c512_qkv_attention_compact`, `mh_attention_project_frag_c512`, `split_projection_frag`) were converted from 8-byte `FragmentPackedMatrix` loads to 16-byte `FragmentPackedMatrixW16` loads, while `split_ffn_one_w2f8` was skipped under the assumption that *"split_ffn_one_w2f8 already uses W16 16B loads"*.

ISA disassembly of `c512-m32-deep.hsaco` (`split_ffn_one_w2f8`) revealed that only the FP32 block input `ar` used `global_load_b128`. All three weight regions of `PackedSplitFfnWeightMixFp8` (`Mix [512][512]`, `Expand 8×[256][64]`, `Contract 8×[64][256]`) were stored in **un-tiled row-major E4M3** and loaded via **256 strided, uncoalesced `global_load_b64` instructions per wave**:
- **Stage 1 (Mix)**: `wm + (g*64 + j*16 + rc())*512 + k + gr()*8` — adjacent lanes `rc() = 0..15` had a **512-byte stride** (16 separate cache lines per wave per `global_load_b64`, 128 `global_load_b64` instructions per wave).
- **Stage 2 (Expand)**: `we + (hb*16 + rc())*64 + ks*16 + gr()*8` — adjacent lanes `rc()` had a **64-byte stride** (64 `global_load_b64` instructions per wave).
- **Stage 3 (Contract)**: `pw + ((ob*16 + rc())*256 + hb*16 + gr()*8)/4` — adjacent lanes `rc()` had a **256-byte stride** (64 `global_load_b64` instructions per wave).

 across 16 C512 blocks × 90 workgroups = 1,440 workgroups (2,880 waves) per frame at `1920×1152`.

## 2. Design & Implementation

1. **Host In-Place `FragmentPackedMatrixW16` Packing (`Development/HIP/hip_reference_network.h`)**:
   - Updated `PackedSplitFfnWeightMixFp8(const std::string& name, bool w16 = false)` under the **same `@split-mix-fp8` cache key** (0 extra VRAM, `weights_count = 184`, `weights_bytes = 297,609,000` bytes).
   - When `w16 == true`, after `Fp8(v, {{0,262144},{262144,131072},{393216,131072}})`:
     - Mix (`offset 0`): `FragmentPackedMatrixW16(v, 0, 512, 512)`
     - Expand (`offset 262144` floats = byte offset `1048576`): `FragmentPackedMatrixW16(v, 262144, 2048, 64)` (8 groups of `256×64` contiguous in row order; each group `g` is `16384` bytes at `wm + 262144*4 + g*16384`)
     - Contract (`offset 393216` floats = byte offset `1572864`): `FragmentPackedMatrixW16(v, 393216, 512, 256)` (8 groups of `64×256` contiguous in row order; each group `g` is `16384` bytes at `wm + 393216*4 + g*16384`)

2. **Device Kernel `split_ffn_one_w2f8_w16` (`hip/c512_m32_deep.inc`)**:
   - **Stage 1 (Mix)**: Loops `gs = 0..15` (`32` K per step), loading `w16_i4 bw` from `wm + ((g*4+j)*16+gs)*512 + (gr()*16+rc())*16` and accumulating `b0` (`k = 32*gs`) then `b1` (`k = 32*gs+16`).
   - **Stage 2 & 3 (Expand + Contract paired by `h2 = 0..7`)**:
     - Prefetches the 4 Contract `w16_i4` fragments `cbw[0..3]` for `ob = 0..3` at `wc + (ob*8+h2)*512 + (gr()*16+rc())*16`, each covering both `hb = 2*h2` (`cbw[ob][0..1]`) and `hb = 2*h2+1` (`cbw[ob][2..3]`).
     - For `hp = 0..1` (`hb = 2*h2+hp`), loads 2 Expand `w16_i4` fragments (`ks2 = 0..1`) from `we + (hb*2+ks2)*512 + (gr()*16+rc())*16`, executes the 4 Expand WMMAs, activation, and 4 Contract WMMAs in the exact same K order as `split_ffn_one_w2f8`.
   - Also tested `split_ffn_one_w2f8_w16_tvec` (`NR_C512_FFN_W16=2`), which stages `out8` through `2048` bytes of LDS to replace 32 `global_store_b8` with 2 `global_store_b128`.

3. **ISA Comparison (`gfx1201`)**:
   - `split_ffn_one_w2f8` (stock): `112` VGPRs, `0` LDS, **256 strided `global_load_b64`** weight loads + 32 `global_load_b128` input loads.
   - `split_ffn_one_w2f8_w16` (`mode=1`): `124` VGPRs (Occupancy 10, 0 spills), `0` LDS, **0 `global_load_b64`**, **128 wave-coalesced `global_load_b128`** weight loads + 32 `global_load_b128` input loads.
   - `split_ffn_one_w2f8_w16_tvec` (`mode=2`): `126` VGPRs, `2048` B LDS, replaces 32 `global_store_b8` with 32 `ds_store_b8` + 2 `ds_load_b128` + 2 `global_store_b128`.

## 3. Gold Gate Verification (`1080p` / `1920×1152`, 3 Frames)

All three modes (`NR_C512_FFN_W16=0, 1, 2`, on top of `NR_C512_W16=2`) produced bit-identical outputs (`out-first.f16` and `out.f16` SHA256 = `0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A`), `record_ok=3`, `accepted=3`, `reject_mask=0`, and `extra_vram_bytes = 0` (`weights_count=184`, `weights_bytes=297609000`).

## 4. 3-Round 4-Slot ABBA Results (`240` Frames / Slot, Drop `80` Warmup = `160` Measured / Slot, `960` Frames / Arm)

### Arm 1: `NR_C512_FFN_W16=1` (`split_ffn_one_w2f8_w16`) vs `NR_C512_FFN_W16=0` (Stock `split_ffn_one_w2f8`, with `NR_C512_W16=2` active on both)

| Round | `A1` Mean | `B1` Mean | `B2` Mean | `A2` Mean | Baseline Mean (`A`) | Candidate Mean (`B`) | $\Delta$ Mean (`B - A`) | $\Delta$ Median (`B - A`) |
|---|---|---|---|---|---|---|---|---|
| `r1` | `9.5254` | `9.4058` | `9.4193` | `9.5692` | `9.5473 ms` | `9.4126 ms` | **`-0.1348 ms`** | **`-0.1425 ms`** |
| `r2` | `9.6077` | `9.4806` | `9.4813` | `9.6177` | `9.6127 ms` | `9.4810 ms` | **`-0.1318 ms`** | **`-0.1340 ms`** |
| `r3` | `9.6177` | `9.4936` | `9.4878` | `9.6181` | `9.6179 ms` | `9.4907 ms` | **`-0.1272 ms`** | **`-0.1270 ms`** |
| **3-Round Aggregate** | — | — | — | — | **`9.5926 ms`** | **`9.4614 ms`** | **`-0.1312 ms` (`-1.37%`)** | **`-0.1345 ms`** |

### Arm 2: `NR_C512_FFN_W16=2` (`split_ffn_one_w2f8_w16_tvec`) vs `NR_C512_FFN_W16=0`

| Round | `A1` Mean | `B1` Mean | `B2` Mean | `A2` Mean | Baseline Mean (`A`) | Candidate Mean (`B`) | $\Delta$ Mean (`B - A`) | $\Delta$ Median (`B - A`) |
|---|---|---|---|---|---|---|---|---|
| `r1` | `9.5734` | `9.4679` | `9.4664` | `9.6079` | `9.5907 ms` | `9.4672 ms` | **`-0.1235 ms`** | **`-0.1310 ms`** |
| `r2` | `9.6214` | `9.5003` | `9.5211` | `9.6481` | `9.6348 ms` | `9.5107 ms` | **`-0.1241 ms`** | **`-0.1280 ms`** |
| `r3` | `9.6523` | `9.5467` | `9.5407` | `9.6651` | `9.6587 ms` | `9.5437 ms` | **`-0.1150 ms`** | **`-0.1285 ms`** |
| **3-Round Aggregate** | — | — | — | — | **`9.6280 ms`** | **`9.5072 ms`** | **`-0.1209 ms` (`-1.26%`)** | **`-0.1292 ms`** |

## 5. Verdict

- **Keep `HIP_C512_FFN_W16 = 1` (`split_ffn_one_w2f8_w16`) as the production default**: wins **3/3 ABBA rounds** by **`-0.1312 ms` mean / `-0.1345 ms` median** (`9.5926 ms -> 9.4614 ms`, best round `9.4126 ms`), bit-exact on all 3 Gold frames and all 24 ABBA edge dumps, with `0` extra VRAM bytes.
- Combined with `c512-w16-20261014` (`-0.0725 ms`), converting all four C512 kernels to `FragmentPackedMatrixW16` saves **`-0.2037 ms` / frame** at `1080p` (`9.68 -> 9.46 ms`).
- `mode=2` (`_tvec`, LDS-staged `global_store_b128` epilogue) also wins 3/3 rounds (`-0.1209 ms` vs stock), but is `~0.010 ms` slower than `mode=1` (`-0.1312 ms`) due to the `32 × ds_store_b8 + wave_barrier + 2 × ds_load_b128` overhead on top of `126` VGPRs. Kept as opt-in `NR_C512_FFN_W16=2`.
