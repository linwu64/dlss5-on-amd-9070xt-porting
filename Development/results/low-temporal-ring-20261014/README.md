# NativeLowFrequencyTemporal 64-Slot Ring (`low-temporal-ring-20261014`)

## 1. Audit Summary
- **Why `r.low_temporal.enabled` previously called `r.submit.Flush()` twice per frame**:
  1. `NativeLowFrequencyTemporal` previously held a single `control` upload buffer (256B), a single `heap` (1 SRV descriptor), and a single `motionPin` `ComPtr`. `Prepare()` destroyed and recreated `heap` (`heap.Reset(); CreateDescriptorHeap(...)`) and mapped/overwrote `control` on the CPU before `Record()`, relying on its own internal `ID3D12Fence` (`Wait()` in `Prepare()`, `q->Signal(fence, ++counter)` in `Submitted(q)`).
  2. In `NativeGameFrame::ProcessSubmittedFrame`, `r.submit.Flush()` was called before `r.low_temporal.Prepare(...)` to drain the D3D12 command queue before CPU preparation, and a second `r.submit.Flush()` was called after `r.submit.Submit(...)` before `r.low_temporal.Submitted(r.submit.Queue())`.
- **64-Slot Ring Refactor**:
  - `difference`, `observed`, `observationGuide`, and ping-pong `band[0..1]`, `guide[0..1]` are GPU-only `DEFAULT` heap UAV buffers executed strictly in-order on `r.submit.Queue()` with explicit `NON_PIXEL_SHADER_RESOURCE <-> UNORDERED_ACCESS` transition barriers inside `Record()`.
  - Only CPU-mutated per-frame resources (`heap` descriptor heap, `control` 256B upload buffer, and `motionPin` `ComPtr`) require per-in-flight-frame isolation.
  - `NativeLowFrequencyTemporal` now owns `std::array<Slot, 64> slots` (`control`, `motionPin`, `heap`, `UINT64 fence`), reuses each slot's `heap` and `control` buffer without per-frame `CreateDescriptorHeap`, checks `if (s.fence > submit.Completed()) submit.Flush();` in `Prepare(Submission& submit, ...)`, and records `Submitted(r.submit.LastValue())` without either per-frame `r.submit.Flush()` in `NativeGameFrame::ProcessSubmittedFrame`.
  - Existing `Prepare(ID3D12CommandQueue*, ...)` and `Submitted(ID3D12CommandQueue*)` overloads remain intact for standalone unit tests and `LmxxfNrRuntime.cpp`.

## 2. Verification on `amd9070` (`gfx1201`)
- **Unit Tests**:
  - `test_low_frequency.exe 1`: `PASS low-frequency constant/halfEMA/high complement/reset/exposure/gap/colour reject/zero output`
  - `test_temporal_enhancement.exe 1`: `MODE3 PASS: strength0 cold/warm identity; low1.5/high2 cold gains; independent compression; zero/reset/failed-output guards`
- **Multi-Frame Gold Bit-Exact Check (`12` frames, `DLSS5_RESIDUAL_SEQUENCE=2`, `NR_LOW_TEMPORAL_FIXED_DT=0.016`)**:
  - `sync-mode2` (`NR_LOW_TEMPORAL_RING=0` vs `1`):
    - `out-first.f16`: `0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A` (**0 bit-diff**)
    - `out.f16` (frame 11): `30F1313DA9FFFDEB6F0477E3AEED5FC7B838CF3AB57635EAA3901524E018EDCC` (**0 bit-diff**)
  - `sync-mode3` (`NR_LOW_TEMPORAL_RING=0` vs `1`):
    - `out-first.f16`: `A7B0DDB8EF8186BB297A2B741546903F8AE7F387D4CEC7D140CAFCBD123DC45F` (**0 bit-diff**)
    - `out.f16` (frame 11): `5008EF28D19423545DEF5194AD7C486E482E838FB57364455F18EDF26A319B9C` (**0 bit-diff**)
  - `async-mode2` (`DLSS5_TEST_ASYNC_SUBMIT=1`, `NR_LOW_TEMPORAL_RING=0` vs `1`): **0 bit-diff** (identical SHA256 to `sync-mode2`)
  - `async-mode3` (`DLSS5_TEST_ASYNC_SUBMIT=1`, `NR_LOW_TEMPORAL_RING=0` vs `1`): **0 bit-diff** (identical SHA256 to `sync-mode3`)
- **ABBA Timing (`MODE 3`, 24 frames, 20 steady frames/slot, 3 rounds)**:
  - Default synchronous `r.submit` (`sync`):
    - `ring=0` 6-slot mean of medians: `10.779 ms`
    - `ring=1` 6-slot mean of medians: `10.776 ms` (`-0.003 ms`)
  - Deferred ring `r.submit` (`DLSS5_TEST_ASYNC_SUBMIT=1`, `async`):
    - Round 1: `ring=0` `10.878 ms` vs `ring=1` `10.806 ms` (`-0.072 ms`)
    - Round 2: `ring=0` `10.862 ms` vs `ring=1` `10.802 ms` (`-0.060 ms`)
    - Round 3: `ring=0` `10.991 ms` vs `ring=1` `10.914 ms` (`-0.077 ms`)
    - **6-slot mean of medians**: `10.910 ms -> 10.840 ms` (**`-0.070 ms / frame`**, winning 3/3 rounds).
