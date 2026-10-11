# ViT contract → QKV tile-ready: real overlap, negative pair result

Base production `30040d4c`, isolated branch `vit-tile-ready`. No production shader, default, DLL, game, driver or deployment changed.

The original 640-token contract (640 ×32-thread WG) and QKV (768 ×160-thread WG) remain mathematically identical. Each contract WG writes one 16-token×64-column block; its release/acq_rel contribution joins 16 column blocks into a ready tile. QKV is dispatched via actual `hipExtModuleLaunchKernel(...flags=1)`; its five waves acquire their own live tile, then join a uniform WG barrier before the unchanged shared-weight/MMA work. Per-pair counters are freshly reset and buffers retained through synchronization. Waits are bounded; failures reject the entire pair.

Real GPU proof: 40675/PID2592 passed original twice, ready ordered, ready any-order twice: all 655,360 contract bytes and 1,966,080 QKV bytes exact, finite and counters/status valid. A strengthened marker (77445/PID25032) consumes and finishes storing the first MMA result before reading GPU-global realtime: 36 and 157 consumer WG completed that first MMA before the last producer's pre-publication marker; ordered control had zero. Thus useful matrix work really overlaps, rather than just a spinning consumer. This is a diagnostic trace, not a speed result. Only 640 tokens were hardware-tested; other full-16-token tail mappings were CPU audited, not admitted.

One trace-off short pair ABBA, 10 warmups+20 samples per slot, initially used asymmetric out-of-window status copies (72359); retained but excluded from the conclusion. The single authorized fairness correction (31969/PID23052, exit0/lock released) gives both variants identical small readbacks between pairs. Necessary counter/status resets remain inside the candidate's GPU and host timing windows. ISA has no realtime instructions; trace pointer is null. All eight slot-edge full-output gates passed.

| Pair mean | Original | Tile-ready | Candidate − original |
|---|---:|---:|---:|
| GPU outer | 70.043µs | 95.770µs | +25.727µs (+36.7%) |
| Host record/submit/completion | 106.475µs | 141.603µs | +35.128µs |

Both candidate GPU slots (97.168/94.372µs) were slower than both controls (76.642/63.444µs). Control drift was −13.198µs, so this small experiment is not a precision estimate of the penalty; it is enough to reject a promising speedup. Forty measured samples per variant do not establish a stable p99. The first diagnostic's 0.643ms outlier is retained. Costs of resets, atomics, acquire invalidations, waits and changed scheduling are not individually isolated, so no single-cost attribution is claimed.

**STOP: no whole-frame ABBA, no integration, no further variants.** This result shows the proposed synchronization mechanism works on this driver/shape but is not profitable in this bounded implementation. Pair microtiming is not APP/FPS, and does not rule out every possible scheduling design.

## Reproduction and evidence

`prepare.py --output <persistent-build> --trace 1|0` derives extra exports from the current recipe; `source.json` locks all original defines. COMGR uses existing `D:\DLSSNR-Lab\build-0927\rtc_compile.exe`; `build.ps1` applies idle/disk/lock/watchdog guards. `pair.cpp` and `timing.cpp` build with `x86_64-w64-mingw32-g++-posix -std=c++17 -O2 -static -I Development/HIP ...` against the original HIP API. `stage.py` copies hash-locked persistent fixtures. `run.ps1` is diagnostic; `run_timing.ps1 -Case pair-abba-fair -Exe pair-fair.exe -Manifest fair-manifest.json` is the completed symmetric case. Existing result directories reject reruns; a deliberate reproduction must use a new case directory and preserve these results.

Local large artifacts/ISA/raw: `/home/lmxxf/work/dlss5-vit-tile-ready-build/`; remote: `D:\DLSSNR-Lab\vit-tile-ready{-math-diag,-timing}-20261012`. Small source identities, executable/module hashes, raw-file hashes, CSV, logs and actual terminal handles are under `results/`; independent source/ISA and geometry review is under `audit/`; independent overlap and timing analysis under `measurement/`. These captured fixtures are the original 877e contract→QKV input/weights/skip, not synthesized random inputs or a mixed FastTwin module. No large weights/binaries/raw tensors are committed.

Clock references: [LLVM message IDs](https://github.com/llvm/llvm-project/blob/main/llvm/lib/Target/AMDGPU/SIDefines.h), [LLVM realtime-message lowering](https://reviews.llvm.org/D127315), and [GPU-global realtime semantics](https://doc.rust-lang.org/core/arch/amdgpu/fn.s_memrealtime.html). Gfx12 does not expose the older `s_memrealtime` instruction: its initial compile failure is preserved, and the successful code uses message131 instead.
