# Independent result: STOP

The corrected first-WMMA-completed trace (77445) observed 36 and 157 consumer WGs finishing their first WMMA before the final producer pre-release-RMW timestamp; ordered control observed zero. All records were complete and bounded waits finished. Publication timestamps are conservative lower bounds. This proves real computation overlap in the instrumented pair, not a speedup.

The sole fair trace-off ABBA (31969) completed all four slots, each 10 warm + 20 measured samples, with all eight first/last contract and QKV byte/finite checks zero. Candidate reset costs are inside both GPU and wall windows. Both variants perform the same two small D2H status copies outside the windows; this remains an isolated synchronized pair, not a streaming fullFrame benchmark.

| Measured scope | Original | Tile-ready | Candidate minus original |
|---|---:|---:|---:|
| GPU mean | 0.070043 ms | 0.095770 ms | +25.727 µs (+36.73%) |
| CPU submit-to-completion wall mean | 0.106475 ms | 0.1416025 ms | +35.1275 µs |
| GPU p99 (40 samples/variant) | 0.113954 ms | 0.1121364 ms | −1.8176 µs |
| Wall p99 | 0.153899 ms | 0.205453 ms | +51.554 µs |

Both candidate slot GPU means (0.097168, 0.094372 ms) exceeded both original slot means (0.076642, 0.063444 ms). Original A2−A1 drift was −13.198 µs. Small-sample tail estimates do not overturn the negative mean and wall result. Stop here: no fullFrame performance test, promotion, deployment or additional tuning cycle.

Original asymmetric case 72359 is retained separately. Its apparent mean gain is not accepted: original control drift −155.99 µs exceeded the apparent −46.9715 µs delta, and the original median was lower than the candidate median. The sole fair correction replaced this result for decision-making.

`results-31969/` binds the actual CSV, logs, executable/module/input/weight manifest, source SHA and statistics. `results-77445/` binds the stronger trace evidence. Reproduce statistics with `python3 analyze_pair.py results-31969/samples.csv results-31969/statistics.json --symmetric-readback`; parsing does not run a GPU task. No API-level causal attribution follows from this bounded result.
