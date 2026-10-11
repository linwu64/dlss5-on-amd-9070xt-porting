# Tile-ready measurement contract (CPU preparation)

No GPU result or performance claim yet. The standalone pair is not a production Frame benchmark.

## Admission before timing

- Lock original/candidate source, full module SHA, actual function, typed ABI, weights/input hashes, token geometry, seed and all launch dimensions. Record both launches' actual API/flags, not merely requested PDL. Candidate consumer uses explicit any-order flag 1; baseline exports remain independent original kernels.
- Two original HIP references and candidate full contract/QKV outputs must match bytes, be finite, and retain tail canaries. Counters/diagnostics are fresh per invocation and stay owned until stream completion. Tail geometry is a separate bounded correctness case.
- Waiting consumer entry before final producer publication proves concurrent residence only. Useful overlap requires its **post-acquire, post-WG-barrier QKV work-start** before the last producer publication, followed by every producer/consumer completion and no timeout. A ready timestamp taken before the uniform WG barrier cannot stand in for work-start.
- Timestamp records must use the same validated GPU-global realtime counter with its units/source recorded. Different-CU cycle counters are insufficient. Record producer start/publication and consumer enter/work-start/end; preserve invalid/poison/missing records and bounded-wait status. The parser reports observed overlap only, never throughput benefit.
- Diagnostic stores/timestamps perturb scheduling. Disable them for any timing comparison. Use symmetric outer events only, no event between contract and QKV; event time includes queue/feeding gaps. Keep upload, allocation, initialization, readback, CSV and cold PSO/module work outside the timing window; required per-frame flag reset remains charged.

## Existing baselines and next conditional step

`host/hip_warm/baseline.cpp` in the current HIP-to-DX12 experiment forces pulse=0. Its production-selector preserves PDL, but the old actual log is requested=1/effective=1/calls=0. It does not establish production APP PulseAuto behavior.

`Development/HIP/benchmark_vit_reuse.cpp` restores frozen HDR before its wall window, measures complete ProcessSubmittedFrame plus submission completion, and reads output outside the window. Its usage text says 900p but actual flags/geometry determine the case. Reuse its current private-copy Frame route only after pair gold/useful overlap passes; retain the production Auto2 selector and PDL selection on both sides, record actual pulse accepted/record counts and PDL calls. No newly inserted per-kernel logs/events in timing. Pulse eligibility changes must be disclosed, not hidden by disabling the baseline marker.

A subsequent short ABBA must keep the same full71/MP1/AE0/historyoff/style/seed/geometry, same HDR and raw first/last hashes, same codec/interop and all unrelated modules. Only the pair implementation and necessary flags/reset costs differ. Report pair GPU time, full-network GPU/wall and full-Frame wall separately; no game FPS inference and no graph/pulse additive accounting.

## Timestamp parser schema

`check_overlap.py report.json` expects `clock_scope: gpu_global_realtime`, `clock_units` (or caller field `units`), `clock_source`, `wait_timeouts: 0`, `producers: [{id,start,published}]`, and `consumers: [{id,enter,work_start,end}]`. Counts are checked against `expected_producers`/`expected_consumers`. `work_start` is after all required acquire operations and the WG barrier. The caller must certify that this timestamp directly precedes useful QKV math. Counter wrap is not supported: bounded captures spanning wrap are invalid.
