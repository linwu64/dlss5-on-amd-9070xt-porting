# Decoder byte edge and W16 FP8 (2026-10-17)

PASS: block47 -> Up48 byte edge, Up39/48 FP8 W16 weights, same K16 accumulation/part sums and wide epilogue. Default decoder mode 3; mode 0 retains previous path. Modules lacking the new exports fall back as a producer/consumer pair. Packed weights reuse @decoder-f16r without increasing capacity.

1920x1152 full Frame, Style1 FAST1 full71 MP1 AE0 history off, seed0, original HDR input FA3C1873..., EagerAuto accepted 240/slot; all first/last raw hashes 0900E489...0F4A, finite/repeat pass. CPU host is benchmark_live_capture.cpp built O2/MinGW, candidate source at e8067a8c plus explicit new decoder launch geometry. CPU preparation for later candidates is dormant (all their switches zero); same host/modules on both arms.

Three ABBA rounds, 240 frames/slot, discard 80, 960 steady samples/arm:

|Round|Mean delta ms|p99 delta ms|
|---|---:|---:|
|1|-0.022087|-0.029038|
|2|-0.012966|-0.008255|
|3|-0.017142|-0.029330|
|Pooled|-0.0173984375|-0.023962|

Pooled mean 9.1687597917 -> 9.1513613542 ms. Round2 control drift -0.1036ms is retained; no claim that all slot pairs win. Timing samples and raw SHA/module identities are in evidence.json. Raw CSV and outputs remain D:\DLSSNR-Lab\five-bitexact-20261017\c1-abba-r{1,2,3}.

Before native compilation, c1-gold exercised old-module fallback only; it does not validate new W16 exports. Initial compile attempts failed due to RTC path and a PowerShell null ExitCode; the successful process wrapper uses Diagnostics.Process. c1-native-gold is the new COMGR Gold. No game installation or published archive changed.
