# C512 W16 (`global_load_b128` 16B Weight Fragments): Gold & 3-Round ABBA Verification (PASS)

Date: 2026-10-14  
Results directory: `Development/results/c512-w16-20261014/`  
Device: AMD Radeon RX 9070 XT (`gfx1201`), Driver `32.0.22029.9039` (`amdhip64_7.dll` ROCm 7.0.2 CLR)

## 1. Mechanism & Zero-Extra-VRAM Design

In the 16 Encoder + Decoder C512 blocks (`23..30` and `40..47`), `CompactC512Body` executes three weight-fragment consumers after `split_ffn_one_w2f8` (`which already uses W16 16B loads`):
1. `split_projection_frag` (`deep_fast-packed-fast.hsaco`): `[512][512]` E4M3 FFN projection.
2. `c512_qkv_attention_compact` (`c512-m32-mh.hsaco`): `[3*512][512]` E4M3 fused QKV + window attention.
3. `mh_attention_project_frag_c512` (`multihead-fast-padded-wave-packed.hsaco`): `[512][512]` E4M3 attention projection.

Previously, these three kernels packed their `[N][512]` E4M3 matrices with `FragmentPackedMatrix`: each 512B tile (`16 rows x 32 k`) arranged as `[h=0..1][gr=0..1][lane16][8B]`, so each lane issued **two separate 8-byte `global_load_b64` loads** (`h=0` at offset `+0` and `h=1` at offset `+256`) per 32-k step (`64` 8-byte loads per wave in `split_projection_frag` and `mh_attention_project_frag_c512`, `192` 8-byte loads per wave in `c512_qkv_attention_compact`).

Using `FragmentPackedMatrixW16` (`[gr=0..1][lane16][h=0..1][8B]`), the two 8-byte fragments `b0` (`k+0..15`) and `b1` (`k+16..31`) of the same lane are contiguous 16 bytes inside the same 512B tile:
- Each 32-k step loads `b0, b1` with **one 16-byte `global_load_b128` (`int4` `__builtin_memcpy`)**, cutting weight VMEM load instructions in half (`64 -> 32` per wave in FFNProj / AttnProj, `192 -> 96` per wave in QKV) while keeping the exact same `k=0, 16, 32, ..., 496` WMMA accumulation order and rounding.
- **Zero Extra VRAM (`0 bytes`)**: `PackedSplitProjectionFrag(name, w16)` and `PackedMhWeightQkvFrag(name, 512, w16)` pack in-place under the existing `name + "@proj-frag"` and `name + "@qkv-frag"` keys (`weights_count = 184`, `weights_bytes = 297,609,000 B`, identical to 0.42).
- Two unroll variants were evaluated for `mh_attention_project_frag_c512_w16`:
  - `HIP_C512_W16 = 1` (`u2`): `_Pragma("unroll 2")` on `mh_attention_project_frag_c512_w16` (`81` VGPRs vs stock `80` VGPRs, `0` spills).
  - `HIP_C512_W16 = 2` (`u4`, **default**): `_Pragma("unroll 4")` on `mh_attention_project_frag_c512_w16_u4` (`97` VGPRs, `0` spills), `_Pragma("unroll 4")` on `split_projection_frag_w16` (`100` VGPRs vs stock `99`, `0` spills), and `c512_qkv_attention_compact_w16` (`187` VGPRs, identical to stock `187`, `0` spills).

## 2. Full-Frame Gold Verification (`PASS`)

Scope: `1920x1152` (`DLSS5_NETWORK_HEIGHT=1080`, `DLSS5_NETWORK_1080_ROWS=1152`), `DLSS5_FAST_NUMERIC=1`, `DLSS5_HIP_PDL=1`, `DLSS5_HIP_SUBMIT_PULSE=auto`, `DLSS5_MULTI_PASS=1`, `DLSS5_TEMPORAL_MODE=0`, 3 repeat frames per role (`frame-gold/`).

| Role | `NR_C512_W16` | `out-first.f16` & `out.f16` SHA256 | `w16_blocks / stock_blocks` | `weights_count` | `weights_bytes` | `submit_pulse` |
| :--- | :---: | :--- | :---: | :---: | :---: | :---: |
| `baseline` | `0` | `0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A` | `0 / 48` | `184` | `297,609,000` | `record_ok=3 accepted=3 reject_mask=0` |
| `candidate-u2` | `1` | `0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A` | `48 / 0` | `184` | `297,609,000` | `record_ok=3 accepted=3 reject_mask=0` |
| `candidate-u4` | `2` | `0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A` | `48 / 0` | `184` | `297,609,000` | `record_ok=3 accepted=3 reject_mask=0` |

All outputs are 100% finite (`invalid=0`, `changed_half_values_from_first=0`) and bit-for-bit identical to the 0.42 Gold SHA (`0900E489...`).

## 3. 3-Round 4-Slot Interleaved ABBA Performance (`PASS`)

Protocol: `baseline-A1 -> candidate-B1 -> candidate-B2 -> baseline-A2`, `240` frames/slot, discard first `80` warmup frames, measure `160` steady frames (`320` steady frames/arm/round, `960` steady frames/arm across 3 rounds), single process per slot under `D:\DLSSNR-Lab\gpu.lock`.

### 3.1 `HIP_C512_W16 = 2` (`u4`, Production Default)

| Round | Baseline Mean (`A1` / `A2`) | Candidate `u4` Mean (`B1` / `B2`) | $\Delta$ Mean (`B - A`) | $\Delta$ Median | $\Delta$ p90 | $\Delta$ p99 | Pairwise (`B1-A1` / `B2-A2`) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Round 1** | `9.6033 ms` (`9.5919` / `9.6147`) | `9.5892 ms` (`9.5829` / `9.5955`) | **`-0.0141 ms` (`-14.1 µs`)** | `-11.0 µs` | `-16.0 µs` | `-20.0 µs` | `-9.0 µs` / `-19.2 µs` |
| **Round 2** | `9.6223 ms` (`9.6078` / `9.6368`) | `9.5912 ms` (`9.5944` / `9.5880`) | **`-0.0311 ms` (`-31.1 µs`)** | `-27.5 µs` | `-28.0 µs` | `-20.0 µs` | `-13.4 µs` / `-48.8 µs` |
| **Round 3** | `9.5954 ms` (`9.5943` / `9.5964`) | `9.5905 ms` (`9.5920` / `9.5889`) | **`-0.0049 ms` (`-4.9 µs`)** | `-6.0 µs` | `-5.0 µs` | `+21.0 µs` | `-2.3 µs` / `-7.5 µs` |
| **3-Round Pooled (960f/arm)** | **`9.6070 ms`** | **`9.5903 ms`** | **`-0.0167 ms` (`-16.7 µs`)** | **`-14.5 µs`** | **`-17.0 µs`** | **`-5.0 µs`** | **6/6 pairs negative (`< 0`)** |

*(In isolated `benchmark.exe` micro-timing at `1920x1152`, `u4` also reduced net NN time by **`-0.088 ms`**.)*

### 3.2 `HIP_C512_W16 = 1` (`u2` Alternative)

| Round | Baseline Mean (`A1` / `A2`) | Candidate `u2` Mean (`B1` / `B2`) | $\Delta$ Mean (`B - A`) | $\Delta$ Median | $\Delta$ p90 | $\Delta$ p99 | Pairwise (`B1-A1` / `B2-A2`) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Round 1** | `9.5877 ms` (`9.5665` / `9.6090`) | `9.5637 ms` (`9.5673` / `9.5600`) | **`-0.0241 ms` (`-24.1 µs`)** | `-20.5 µs` | `-49.0 µs` | `-50.0 µs` | `+0.8 µs` / `-49.0 µs` |
| **Round 2** | `9.5787 ms` (`9.5813` / `9.5761`) | `9.5712 ms` (`9.5701` / `9.5724`) | **`-0.0075 ms` (`-7.5 µs`)** | `-5.0 µs` | `-16.0 µs` | `-12.0 µs` | `-11.2 µs` / `-3.7 µs` |
| **Round 3** | `9.6041 ms` (`9.6012` / `9.6071`) | `9.5913 ms` (`9.5861` / `9.5965`) | **`-0.0128 ms` (`-12.8 µs`)** | `-13.5 µs` | `-16.0 µs` | `+14.0 µs` | `-15.1 µs` / `-10.6 µs` |
| **3-Round Pooled (960f/arm)** | **`9.5902 ms`** | **`9.5754 ms`** | **`-0.0148 ms` (`-14.8 µs`)** | **`-13.0 µs`** | **`-27.0 µs`** | **`-16.0 µs`** | **5/6 pairs negative** |

## 4. Audited & Rejected Companion Ideas (Recorded in `failed-experiments.md`)

1. **ViT (`blocks 31..38`) `vit_stream_contract_frag_bout_compactw_w16` & `vit_stream_project_n64_bb_compactw_w16`**:
   - Audited with LLVM 23 (`compile-modules.py --only vit-stream vit-stream-fast --targets gfx1201 --target-feature=-real-true16`): `_Pragma("unroll 4")` W16 inflates `vit_stream_contract_frag_bout_compactw` VGPRs from `211 -> 251` (at the 256-VGPR ceiling) and `vit_stream_project_n64_bb_compactw` VGPRs from `161 -> 220`, dropping wave occupancy on `vit_stream_project_n64_bb_compactw` from 3 waves/SIMD (`<=170` VGPRs) to 2 waves/SIMD (`220` VGPRs). Meanwhile, ViT's largest matrix (`vit_stream_qkv_f8w_bin`, `3x1024x1024`) already uses W16 (`global_load_b128`) in 0.42. Not merged.
2. **C256 `SpStage` Boundary Expansion (`blocks 15, 22, 48, 55`) & `sp_init` / `sp_recover` Merge**:
   - Encoder `block 15` takes FP32 (`ByteIn=false`) from `Down(14)` and `block 22` outputs FP32 `Hrtz(v)` (`PostMode=3, ByteOut=false`) into `skips[3]` and `Down(22)` — incompatible with `sp_run256_w16` (`ByteIn=true, ByteOut=true, PostMode=4`).
   - Decoder `blocks 48` & `55` run `c256_wave2_bi_bo_w16` from `c64-wave2-fast.hsaco` (LLVM 23, `W2_QKV_FUSE=3`, `W2_FFN_QT_BATCH=4`, `W2_HOIST_LOADS=15`, `W2_FAST_NUM=3`), whereas `SpStage(49, 6)` at 1080p loads `swin-persistent.hsaco` (COMGR, `W2_QKV_FUSE=0`, `W2_FFN_QT_BATCH=2`, `W2_HOIST_LOADS=0`, `W2_FAST_NUM=0`). Folding `48`/`55` into `SpStage` changes their numerical contract (`W2_FAST_NUM=3 -> 0`), breaks 0.42 Gold (`0900E489...`), runs a slower per-layer recipe, and adds `+4.42 MB` persistent output buffer VRAM.
   - Exporting `sp_init_pair` is explicitly rejected by `CheckPulseCapabilities()` (`hip_reference_network.h:1006`, disables `submit_pulse=auto`), and `sp_recover256_w16` is the `<1.5 µs` async 1-WG timeout guard that replaced CPU `hipStreamSynchronize`. Not modified.
