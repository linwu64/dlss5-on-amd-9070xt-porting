# Production Auto host timing — bounded result (2026-10-12)

**Useful only for coarse host-call elapsed time. Zero disturbance and GPU idle/stage attribution were not established.** No optimization, deployment, driver change or new GPU trace tool was introduced. Product code is unchanged; the generator makes private host copies from99fc33ba, retaining the joint43-module/current resource path.

ElevenQPC points wrap existing CPU calls. Storage is preallocated, no per-frame extra export/heap allocation, and data is dumped after allframes. No GPU event/query/marker/wait was added; no Auto guard was bypassed. Gold95980 passed3frames/arm. SoleA/A31627 passed numerical/path checks: sameexe off/on/on/off,320frames/slot discard80,8edge0900/finite/repeat0, actualAutoaccepted320/reject0/PDLcalls0,43expected moduleSHAs unchanged. Originalhelper/scaffold branches also exist inoff; A/A is incremental diagnostic disturbance, not proof the scaffold costs nothing.

## Disturbance screen

480/arm: meanoff9.6242125→on9.647700ms (+23.4875µs), p999.83788→9.84263ms (+4.750µs), max9.945→9.920ms. ControlA2−A1mean drift+28.725µs; markedB2−B1+9.675µs. SlotmeansA1/B1/B2/A2=9.609850/9.6428625/9.6525375/9.638575ms. **Both marked slots exceed both controls:** retain a positive interference possibility; this one shortscreen cannot separate roughly24µs excess from time-varying drift. It is not strictzero-overhead admission and not suitable for finefew-µs optimization claims. No repeat was run.

## What the marked480frames show

| Existing host interval | Mean elapsed ms |
|---|---:|
| Input recording/submission call |0.034049|
| Afterinput untilHIPenqueue |0.026554|
| `Network::Enqueue` API call |0.354308|
| RemainingBridge tail |0.022157|
| Output recording/submission call |0.019855|
| Originalcaller emptySubmit+Flush completion action |9.188284|

TotalQPC9.647225ms versus originalwall9.647700ms (endpoint difference~0.475µs). Intervals may include original waits/driver activity: **9.188ms is not removableCPUwork, GPU execution time or aGPUgap**. Nor is0.354ms the GPUcost of neural kernels. This controlled serialcompletion harness does not establish gamequeue overlap. GoldMemory1/firstframe coldwork are excluded; only markedAAframes after80 are summarized.

No currently validated low-disturbance, HIPqueue-visible, calibrated externaltrace was found in the existing evidence. GPUbusy/idle and internalGPUstage distribution remain unobservable here. The one next suggestion is to assess an actualGPU schedulingtrace capability before choosing another optimization; do not derive it by subtracting CPUintervals or expand this into a profiler.

Evidence: [independent results and original smallCSV/logs](measurement/RESULTS.md), [mechanism audit](audit/review.json), [frozen source/build](results/build/). `prepare.py` emits the private host, `run_gold.ps1` and `run_aa.ps1` preserve guarded actualruns at `D:\DLSSNR-Lab\auto-host-timing-20261012`; unique-case guards prevent silent overwrites. Large exe/raws stay outsidegit. Installed64dc/MODE0/1x is unchanged; no further GPUwork is queued.
