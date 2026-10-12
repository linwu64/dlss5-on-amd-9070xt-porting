# Bound and compact — final result (2026-10-12)

Two independent optimizations were tested on RX 9070 XT with the current 1152/640 full71 Frame, frozen real HDR, Auto2 and requested PDL1 (actual PDL calls0). No game payload or release was changed.

| Candidate | Numerical result | Complete Frame result | Decision |
|---|---|---|---|
| C32 NoHi, seven SHA-certified weights; other three stock | Half-domain primitive, mapped unit, three Frame gold and ABBA eight edge gold all pass | wall9.6336771→9.6284083ms; −5.269µs versus baseline drift47.546µs; p99−17.790µs | Correct but no reliable gain; STOP, not integrated |
| Eight packed ViT expand weights, 16→4MiB each | Unit and complete Frame byte-identical, eight compact keys and no legacy duplicate | held weight capacity−96MiB; wall9.633050→9.6346917ms, no stable speed gain | Narrow default loader integration as resource improvement |

Each ABBA used four320-frame processes, discarded80 per process,480 measured samples per arm. These are complete controlled Frame wall times, not game FPS or pure GPU kernel times. Capacity and driver-free snapshots do not measure resident peak. B48281 original wrapper exit1 was a PowerShell nested-array identity-check bug: all four child exits/gold passed and independent read-only comparisons verified43 unchanged module names/sizes/SHAs; original evidence remains, no GPU rerun.

Sources, proofs, exact identities and original small logs/CSVs are in [A](../c32-score-nohi/) and [B](../packed-weight-compact/). `run_a_frame_timing.ps1` preserves the actual A25355 guarded wrapper. A reproducibility requires its original pre-B baseline header, not silently rebuilding against the new B loader. Unknown B names/layouts and preexisting legacy cache entries keep the old loader; `HIP_COMPACT_VIT_EXPAND=0` restores its original path. No additional performance variants are queued.
