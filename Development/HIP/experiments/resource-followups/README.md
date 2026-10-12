# Sequential resource followups — final (2026-10-12)

All three authorized directions are concluded. Sources and evidence are delivered; **installed64dc, MODE0/MP1/1x and release0.41 are unchanged. Nothing from this round was deployed or pushed.** Starting production was abacaaed, already including the earlier96MiB expand saving.

| Direction | Actual resource result | Decision |
|---|---|---|
| Explicit NeverHistory session | One35,389,440B shared history buffer/import omitted (33.75MiB); freshcandidate created2/imported2/poolhits0 | Adopt; unknown/history-capable callers retain old path |
| C512 unused mixed/contract New | Full Frame gold0, but pool290,571,128→292,742,008B (+2,170,880B), same27tensors; driverfree only+64KiB | STOP, shared change reverted; no timing round or pool variant |
| Compact contract live tail | Eight packed buffers16MiB+4KiB→4MiB+4KiB, actualweights−96MiB | Adopt as resource improvement |
| Compact projection live tail | Eight4MiB+4KiB→1MiB+4KiB, actualweights−24MiB with contract already on | Adopt as resource improvement |

Final production66725 used one formal host, old/new43-module paths, no privateNR flags and no sidecar. Six complete Frame outputs match accepted0900 SHA, finite/repeat0, Auto3; oldmodule selects zero new keys, newmodule8+8. Weight capacity423,438,120→297,609,000B, **net120MiB beyond the prior expand saving**. Pool/gather/noise unchanged, history0. Driver-free snapshots are different counters: stage1+67.5MiB, contract+96MiB, projection+32.5MiB, finalcombined+128.5MiB. They are not a resident peak or proof of hidden physical copies, and are not added to capacity savings.

## Timing boundary and original tails

One A-B-B-A per adopted direction,320 Frames/process, first80 discarded,480 samples/arm. Frozen realHDRfa3c, current1152/640/full71/Style1/seed0, Auto2/PDL requested1 with actualcalls0. Wall covers the complete existing NativeGameFrame through completion; cold setup, upload restoration and first/last readbacks are outside the measured window. This is neither gameFPS nor GPU kernel sum. Projection baseline already enables contract; the three effects are not added.

| Direction / actual handle | Mean old→new ms | p99 old→new ms | Max old→new ms | Control / candidate mean drift µs |
|---|---|---|---|---|
| History36250 |9.642621→9.646217|9.844420→9.836000|11.289→9.896|+26.392 / +20.025|
| Contract67984 |9.651219→9.642650|9.880680→9.837990|9.924→10.182|+46.113 / −14.992|
| Projection30592 |9.658092→9.656335|9.869890→9.858420|10.068→10.255|+26.492 / +22.538|

Mean changes are smaller than control drift: **no reliable speedup is claimed**. Single maxima worsening by0.258/0.187ms remain visible; these limited runs do not prove universal tail equivalence. No performance retries or final extra performance round were run.

## Source, compatibility and reproduction index

- [History capability and CPU contracts](../history-elision/README.md): publicUnknown keeps allocation, explicitNeverHistory rejects temporal use at every entry, no hot lazy allocation; original history modes and empty-resource lifetime preserved.
- [ViT sources, fixtures and raw small evidence](../vit-weight-tail-compact/README.md): pure packed-prefix/F32-tail movement, same precision/math/order. Pointer layout tags choose matching cached kernels; missingexports, legacycache, unknownselectors and gfx1200 retain old pairs. Internal defaults apply only the validated gfx1201/9070XT profile. Existing `hip/build-modules.ps1` vit_stream recipes naturally include both new exports, with no permanent extra module or user configuration.
- Formal host O2 session99541 and [formal addon O2/source receipt](../history-elision/results/final-addon-20261012/receipt.json)30670 both exit0. [Joint94285 compiler and raw function comparisons](../vit-weight-tail-compact/results/joint-94285/) show all86 original and both accepted87-function candidates unchanged byte-for-byte, with only two exports added.
- [Final build/manifest](results/final-production-build/) and [final guarded runner](run_final_gold.ps1) bind exact source/executable/module/input identities. Remote preserved case `D:\DLSSNR-Lab\vit-tail-production-final-20261012` contains both43-module folders and finalraws; source assets remain `D:\DLSSNR-Lab\combined-vs041-20261006`. Large binaries/raws stay outside git, smallCSV/log/SHA receipts are tracked. Runners reject existing cases; use a separate freshcase root for a deliberate reproduction, never silently overwrite evidence.
- Stage2 rejected source/diff remains in [c512-unused-tensors](../c512-unused-tensors/); its shared header is restored to the original twoNew path. Previous expand compact loader is preserved. No new optimization is queued.
