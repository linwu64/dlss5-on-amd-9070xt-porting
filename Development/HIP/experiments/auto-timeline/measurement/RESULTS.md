# Auto host timeline: bounded descriptive result

Actual gold95980 and A/A31627 exited0/released. Same executable, current43 modules (joint vit-stream da1b), old frozen HDR menu input, full NativeGameFrame/Auto path. This is standalone replay, not a new gameplay capture or game FPS. Eight A/A edge buffers equal accepted0900 SHA; finite/repeat0, Auto320 accepted/reject0 and PDLcalls0 each slot. Wide tables have320rows each, off marks all0, on11positive monotone ticks, QPCfrequency10MHz; saved wall values match original CSV within its rounding. Source audit found no new GPU commands/synchronization; the runtime summary alone is not that proof.

One0–1–1–0 screen,320frames/slot discard80,480steady observations/arm:

| Slot | Mean ms | p99 ms | Max ms |
|---|---:|---:|---:|
| Off A1 |9.609850|9.82966|9.945|
| On B1 |9.6428625|9.83915|9.871|
| On B2 |9.6525375|9.84044|9.920|
| Off A2 |9.638575|9.84752|9.906|
| Off pooled |9.6242125|9.83788|9.945|
| On pooled |9.6477000|9.84263|9.920|

Marked mean+23.4875µs and p99+4.750µs; controlmean drift+28.725µs, marked drift+9.675µs. **Both marked slots are slower than both controls.** This is a positive disturbance indication; this one screen cannot separate the roughly24µs difference from time-varying drift. It does not prove zero overhead, strict equivalence, or an unchanged GPU schedule. No additional A/A round was run. With480samples/arm, p99 describes about five upper-tail observations.

Marked480sample CPU means:

| Host interval | Mean ms |
|---|---:|
| Input recording + submission |0.034049|
| Before HIP enqueue |0.026554|
| Network::Enqueue API |0.354308|
| Bridge after enqueue |0.022157|
| Output recording + submission |0.019855|
| Caller original empty Submit + Flush completion action |9.188284|
| Remaining host intervals |0.001995|

Outer QPC mean9.647225ms differs from original wall by−0.475µs due to timestamp endpoints/rounding. This difference is **not** a GPU gap. The9.188ms completion action includes original CPU submission/driver/fence waiting; it is not a measured GPU execution duration and cannot simply be removed. Input/output Submit intervals may also include blocking. The0.354ms enqueue interval is host API duration, not summed kernel time. These coarse CPU intervals are descriptive references only.

No current calibrated external GPU schedule trace was available. GPU execution intervals, idle gaps and overlap remain unknown. Do not subtract asynchronous HIP/D3D times or CPU waits to invent them. Cold3frame gold with Memory1 is excluded from performance analysis. No new optimization, production code change, game deployment, driver change or GPU follow-up was performed by this analysis.

Reproduce CPU analysis from the persisted small data:

```
python3 analyze_case.py results/aa-31627 --output /path/to/analysis-output
```

`analyze_host_marks.py` checks raw tick integrity; `analyze_aa.py` preserves slot drift and the positive disturbance indication. `analyze_case.py` additionally checks output edges, runtime counters, flags and43module identity. Raw buffers/models are not committed.
