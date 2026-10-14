# C32 Wave1 Wide Fragment Weight Loads (`c32-w16-20261014`)

## 1. Discovery & Motivation

Following Campaign 1 (`c512-ffn-w16-20261014`, `-0.1312 ms` mean / `-0.1345 ms` median), we audited the remaining network hotspots for uncoalesced or narrow 8-byte `global_load_b64` weight loads (`2.44×` L0 cache request amplification vs mochizuki's Vulkan shaders):
1. **C32 `wave1` (`hip/wave_owned_c32.inc`, `c32-wave1-fast.hsaco` / `c32-wave1-rtz.hsaco`)**:
   - Executed 10 times per frame (`block 0` prefix, `blocks 1..4` encoder chain, `block 66` fused Up, `blocks 67..69` decoder chain, `block 70` fused post) across `8,100` to `32,400` workgroups per launch at `1920×1152` (`0.78 ms` total GPU time).
   - `PackedC32Weight` (`Development/HIP/hip_reference_network.h`) only quantized C32 FFN (`Expand [128][32]`, `Contract [32][128]`) and Attention (`QKV [96][32]`, `OutProj [32][32]`) weights to E4M3 **in un-tiled row-major order**!
   - Consequently, `cw_matrix8` (`offset = row * stride + k + gr * 8`) issued **76 strided `global_load_b64` instructions per wave per block** where adjacent lanes (`rc = 0..15`) had a **32-byte or 128-byte stride**, plus 12 `global_load_b64` instructions for `AppendC32ResidualDiagonals`.
2. **C256 Swin Attention (`hip/wave_owned_mh.inc`, `hip/swin_persistent.inc`)**:
   - Also audited and tested converting `WaveOwnedAttentionWeight(name, 256)` from 8B `FragmentPackedMatrix` to 16B `FragmentPackedMatrixW16` (`c256_wave2*_w16a`, `sp_run256_w16a`). While it eliminated 416 `global_load_b64` instructions per wave with 0 scratch, 3-round ABBA measured flat (`+0.0008 ms` mean across 3 rounds: `-0.0120 ms`, `-0.0036 ms`, `+0.0180 ms`) because the 8-wave (256-thread) workgroup's inter-wave `w2_sync()` barriers and LDS traffic already hide the already-coalesced 8B fragment loads. Reverted and not shipped.

## 2. Design & Implementation (`HIP_C32_W16`)

1. **Host In-Place `FragmentPackedMatrixW16` + `AppendC32ResidualDiagonalsW16` (`Development/HIP/packed_weights.h`, `Development/HIP/hip_reference_network.h`)**:
   - Under the existing `@c32fp8` cache key (`0` extra VRAM, `weights_count = 184`, `weights_bytes = 297,609,000` bytes), when `C32W16Active() == 1` (`HIP_C32_W16=1`, default; override via `NR_C32_W16` / `DLSS5_HIP_C32_W16`):
     - **Attention (`96×32` QKV at offset `0`, `32×32` OutProj at float offset `768`)**: packed in-place with `FragmentPackedMatrixW16(v, 0, 96, 32)` and `FragmentPackedMatrixW16(v, 768, 32, 32)`.
     - **FFN (`128×32` Expand at float offset `512`, `32×128` Contract at float offset `4608`)**: packed in-place with `FragmentPackedMatrixW16(v, 512, 128, 32)` and `FragmentPackedMatrixW16(v, 4608, 32, 128)`, plus `AppendC32ResidualDiagonalsW16(v)` which packs the `kt=0` (`ci=0`) and `kt=1` (`ci=1`) diagonal tiles of each `(part, ci)` into a single 512-byte `W16` tile so one `cw_matrix16` load covers both `kt=0` and `kt=1`.
   - All 26 legacy exports in `c32-wave1*.hsaco` remain 100% untouched for `CheckPulseCapabilities()`; `Fn("c32_wave1", name)` automatically selects `name + "_w16"` when `C32W16Active() == 1`.

2. **Device Kernels (`hip/wave_owned_c32.inc`)**:
   - Added `cw_matrix16(const float* p, uint row, uint stride, uint k, uint group)` which loads a 16-byte `cw_i4` (`global_load_b128`) from `((row/16)*(stride/32) + k/32)*512 + (group*16 + row%16)*16` where all 32 lanes of a wave read **512 contiguous bytes (4 cache lines, 100% wave-coalesced)**.
   - In `W16 == 1` (`_w16`):
     - **FFN Expand + Contract**: Paired `ht` in steps of 2 (`h2 = 0..3`). Each `h2` step loads two `cw_i4` Expand fragments (`eb0`, `eb1`) and two `cw_i4` Contract fragments (`cb0`, `cb1`) with constant immediate offsets (`offset:2048`, `offset:2560`, `offset:18432`, `offset:20480`), computing both `ht = 2*h2` and `ht = 2*h2+1` in the exact same K accumulation order.
     - **FFN Residual Diagonals**: One `cw_i4` load per `(ci, part)` (`6` `global_load_b128` total instead of `12` `global_load_b64`).
     - **QKV (`3×2` tiles) & OutProj (`2` tiles)**: One `cw_i4` load per tile covering both `kt=0` and `kt=1` (`6 + 2 = 8` `global_load_b128` instead of `16` strided `global_load_b64`).
   - Also tested `W16 == 2` (`_w16h`, where Contract remained 8B `FragmentPackedMatrix` to test 128-VGPR boundary); falsified in ABBA (`+0.0285 ms`) because indexing 8B Contract inside the rolled `ht=0..7` loop added 128 dynamic bit-shift ALU instructions and 64 `global_load_b64` instructions per wave.

3. **ISA Comparison (`gfx1201`, `c32_wave1_chain` vs `c32_wave1_chain_w16`)**:
   - `c32_wave1_chain` (stock): `88` `global_load_b64` (76 strided row-major weight loads + 12 diagonal loads), `16` `global_load_b128` (input loads), `126` VGPRs, `0` scratch.
   - `c32_wave1_chain_w16` (`mode=1`): **`0` `global_load_b64`**, **`46` `global_load_b128`** (30 wave-coalesced 16B weight loads + 16 input loads — cutting weight load instructions from `88` uncoalesced 8B loads to `30` coalesced 16B loads!), `136` VGPRs, `0` scratch.

## 3. Gold Gate Verification (`1080p` / `1920×1152`, 3 Frames)

All three modes (`NR_C32_W16=0, 1, 2`, on top of `NR_C512_W16=2` and `NR_C512_FFN_W16=1`) produced bit-identical outputs (`out-first.f16` and `out.f16` SHA256 = `0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A`), `record_ok=3`, `accepted=3`, `reject_mask=0`, and `extra_vram_bytes = 0` (`weights_count=184`, `weights_bytes=297609000`).

## 4. 3-Round 4-Slot ABBA Results (`240` Frames / Slot, Drop `80` Warmup = `160` Measured / Slot, `960` Frames / Arm)

### Arm 1: `NR_C32_W16=1` (`c32_wave1_*_w16`) vs `NR_C32_W16=0` (Stock `c32_wave1_*`, with `NR_C512_W16=2` and `NR_C512_FFN_W16=1` active on both)

| Round | `A1` Mean | `B1` Mean | `B2` Mean | `A2` Mean | Baseline Mean (`A`) | Candidate Mean (`B`) | $\Delta$ Mean (`B - A`) | $\Delta$ Median (`B - A`) |
|---|---|---|---|---|---|---|---|---|
| `r1` | `9.4312` | `9.4029` | `9.4302` | `9.4567` | `9.4440 ms` | `9.4166 ms` | **`-0.0274 ms`** | **`-0.0420 ms`** |
| `r2` | `9.4440` | `9.4424` | `9.4602` | `9.4983` | `9.4712 ms` | `9.4513 ms` | **`-0.0199 ms`** | **`-0.0225 ms`** |
| `r3` | `9.4899` | `9.4717` | `9.4788` | `9.5098` | `9.4999 ms` | `9.4753 ms` | **`-0.0246 ms`** | **`-0.0340 ms`** |
| **3-Round Aggregate** | — | — | — | — | **`9.4717 ms`** | **`9.4477 ms`** | **`-0.0240 ms` (`-0.25%`)** | **`-0.0328 ms`** |

### Arm 2: `NR_C32_W16=2` (`c32_wave1_*_w16h`) vs `NR_C32_W16=0` (1 Round)

| Round | `A1` Mean | `B1` Mean | `B2` Mean | `A2` Mean | Baseline Mean (`A`) | Candidate Mean (`B`) | $\Delta$ Mean (`B - A`) | $\Delta$ Median (`B - A`) |
|---|---|---|---|---|---|---|---|---|
| `r1` | `9.5023` | `9.5469` | `9.5554` | `9.5430` | `9.5227 ms` | `9.5512 ms` | `+0.0285 ms` | `+0.0345 ms` |

## 5. Verdict

- **`HIP_C32_W16=1` (`c32_wave1_*_w16`) is promoted as default**, winning **3/3 ABBA rounds** with **`-0.0240 ms` mean / `-0.0328 ms` median** (`9.4717 ms -> 9.4477 ms` mean, `9.4707 ms -> 9.4378 ms` median), `0` extra VRAM, and bit-exact 3-frame Gold (`0900E489...`).
- Combined with Campaign 1 (`c512-ffn-w16-20261014`, `-0.1312 ms` mean / `-0.1345 ms` median), the two W16 weight-coalescing campaigns today have reduced 1080p full-frame wall time by **`-0.1552 ms` mean / `-0.1673 ms` median** (`9.5926 ms -> 9.4477 ms` mean, single-slot median down to `9.3900 ms`).
