# Five bit-exact optimization candidates — final handoff, 2026-10-17

## Outcome

|Candidate|Decision|Evidence|
|---|---|---|
|1 Block47 byte edge + decoder W16 FP8|Accept|Gold0; three rounds mean/p99 improve; pooled -17.398us/-23.962us|
|2 producer-side ViT gather folding|Stop|Gold0; all three means non-improving, pooled +5.691us|
|3 grouped Down byte LDS + W16 FP8|Accept|Gold0; three rounds mean/p99 improve; pooled -20.704us/-27.539us|
|4 C32 pool four-column wave|Stop|Gold0; all three means regress, pooled +5.546us|
|5 fused Up56/62/66 W16 FP8|Stop|56/62 pooled mean +3.555us, p99 +20.987us; connecting missing65->66 byte edge FAILS Gold, no full-form performance test|

All stopped source remains isolated in the experiment patch/worktree, not production. Production payload source10982cf4 includes1+3 and distinct cache keys for new FP8 layouts versus half fallback. The measured fixed-mode sessions retain the same weight count/capacity; this is not a VRAM peak claim.

## Clean default build verification

Current canonical recipe, RowOpts, Linux LLVM23 prebuilt rows (-real-true16), driver COMGR rows, two architectures40 each. A new target audit caught legacy D:\DLSSNR-Lab\rtc_compile.exe ignoring the gfx1200 parameter: initial COMGR gfx1200 labels contained actual gfx1201 ELFs. Only gfx1200 was rebuilt using current hip/rtc_compile.cpp in an isolated compiler executable; all80 final SHA values and actual ELF architecture flags now pass. All40 tested gfx1201 binaries remain byte-identical across this repair. Initial wrong-target snapshot retained as HIP-before-target-fix.zip, hashes in receipt.json. gfx1200 has compile/ELF verification only.

Full original NativeGameFrame caller, O2 MinGW, frozen1296x720 HDR inputFA3C1873..., internal1920x1152 or1600x960, full71/Style1/FAST1/MP1/AE0/historyoff/seed0/EagerAuto, NET0. Candidate runs have no NR_* overrides: production defaults selected. Baseline uses same host/modules with the two accepted feature switches disabled. Final dedicated Gold reads/checks all3 frames per slot; all are finite/repeatable and equal to their baseline. 1080 raw hash0900E489...0F4A; 900 uses independently computed baseline raw hash, not a NVIDIA900 oracle claim. Per-slot Auto records accepted3 or240, reject0.

## Final combination ABBA

Three rounds x four slots,240 frames/slot discard80,960 measured samples/arm/tier; only first/last readback during timing. Quantiles are linear-interpolated from original rows.

|Tier|Baseline mean ms|Default mean ms|Mean delta us|Pooled p99 delta us|
|---|---:|---:|---:|---:|
|1080|9.142189167|9.121343438|-20.845729|-25.690|
|900|6.569911146|6.535424271|-34.486875|-32.351|

All six round means improve. **1080 round2 p99 regresses+10.599us**; rounds1/3 improve-79.007/-15.963us. This counterexample is retained, not re-run away; do not claim every round/slot tail improves. Both pooled p99 values improve. Separate candidate deltas must not be added to predict the combination. Absolute times from different batches are not comparable; no new game FPS claim.

## Artifacts

- Local: /home/lmxxf/work/dlss5-five-build/final-payload/ — final80 modules, O2 dlss5-amd.addon64 and LmxxfNrRuntime.dll.
- Remote: D:\DLSSNR-Lab\five-final-20261017 — canonical module set, host binaries, receipts, original CSV/raw outputs, shader fixtures and logs.
- SHA/ELF identities: modules-80.json; binaries/source identities: receipt.json; original samples: evidence.json; recomputed statistics: statistics.json.
- Production addon/runtime builds pass. Runtime API smoke passes exit0 against staged modules/assets. Its first attempt lacked native_codec_encode.hlsl in the fixture directory; the original failure logs are retained, then current shaders were staged and the smoke passed. No source fix was inferred from the missing fixture.
- Game-check, disk>=100GB, atomic gpu.lock and15-second game watcher protected every GPU/RTC task. Installed Stellar Blade/Onimusha directories, user configuration and published0.42 archives were not modified. Full distribution ZIPs have not been repackaged/uploaded.
