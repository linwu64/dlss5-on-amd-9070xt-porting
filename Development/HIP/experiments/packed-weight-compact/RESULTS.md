# Expand-only packed-weight storage: resource gate passed

The current1152/640-token full NativeGameFrame owns184 weight cache keys. Replacing only the eight block31..38 fragment expand allocations with their consumed4MiB prefix changes total weight capacity from524,101,416B to423,438,120B: **96MiB reclaimed**. Every changed key has one owned pointer and no simultaneously retained legacy full key. Pool290,571,128B, gather5,242,880B and noise0 are unchanged. The driver free-memory difference was also96MiB in this isolated case; these are requested/held capacities and driver-free observations, **not resident peak VRAM**.

Unit77951 used the unchanged canonical11a25 module and actual captured640-token operands. Full16MiB weight twice, then freed before compact4MiB twice: all four complete2,621,440B FP8 outputs equal captured SHA4f48d3e… with zero finite/repeat/tail-guard differences. The full4194304-byte fragment-address map is a bijection and independent of token count. No quantization, math, module, kernel or ABI changed.

FullFrame21471 used the same real old1296×720 HDR menu capture, current codec/decoder, processing1920×1152, full71/Style1/seed0/MP1/AE0/Mode0, both roles PulseAuto and requestedPDL1. Each role's three frames is finite and identical; all four first/last decoded raws have SHA0900e489…. ActualPulse records=3 per role, PDLcalls=0. This is a controlled replay, not the current game scene.

## One short ABBA: no stable speedup

The only run48281 used the same already-built executables and immutable43 modules: four slots,320frames each, discard80,480steady samples per role. HIP_MEMORY=0; no per-frame extra readback/API/log observer, only first/last output checks. The original benchmark measures ProcessSubmittedFrame through submission completion; it is a **full NR Frame wall scope**, not pure GPU time or game FPS.

| Wall ms | Baseline | Compact | Difference |
|---|---:|---:|---:|
| Mean | 9.633050 | 9.6346917 | +0.0016417 |
| Median | 9.636500 | 9.628000 | −0.008500 |
| p95 | 9.793000 | 9.787050 | −0.005950 |
| p99 | 9.840630 | 9.845470 | +0.004840 |

Control mean A2−A1 drift is+0.0212667ms, greater than the+0.0016417ms pooled mean difference. This short run shows no stable acceleration and no obvious large regression; it does not prove zero tail regression. Resource savings stand separately. Do not repeat formal rounds to search for a speedup or promise improved FPS when memory pressure is absent.

All eight raw edges matched the same gold, each process reported actual320Pulse records/zero rejection and requestedPDL1 with actualcalls0. Each child exited0. The enclosing wrapper exited1 only in its final module check: PowerShell5 `@(Get-Content ... | ConvertFrom-Json)` wrapped the43-file JSON array as one System.Object[], making the subsequent filter compare arrays instead of files. Original wrapper/error/source are preserved. Python exact JSON equality and a read-only PowerShell flat-array comparison prove all43relative names/byte lengths/SHA unchanged; the corrected original guard passed read-only. **No GPU rerun** was used to close this bookkeeping error.

`results/frame-abba-48281/` holds the originalCSV/logs/manifest, statistics, wrapper source and CPUclosure. `results/frame-21471/weight-inventory.tsv` lists all184actual keys, not an old607→236MiB estimate. `PRODUCTION_REVIEW.md` and `production-loader.diff` provide a narrow review-only loader edit with unknown-selector and existing-legacy-key fallback. Integration/default policy belongs to main; no player files, assets or releases have changed.
