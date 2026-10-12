# Contract packed-weight tail relocation experiment

Baseline a5786fbb already contains accepted compact-expand storage and NeverHistory. Contract only; projection is not implemented here.

The actual FP8 fragment matrix occupies bytes [0,4194304). Its 1024 F32 scales originally start at16777216. Compact storage copies exactly those two byte ranges into4198400 contiguous bytes. The new export changes only scale float index4194304 to1048576; old exports retain the template default. CPU exhaustive fragment addressing and live-byte inverse checks are in results/cpu/byte-proof.json.

Actual COMGR96094 exited0 for gfx1201 with empty extra options. Sidecar SHA14facdb57be7b3864b913a99ebe42604c9add4ed4f8bf032b2b04235897ec83f. ELF ABI56B, four pointers at0/8/16/24, three u32 at32/36/40, reuse pointer48; wave/WG32, LDS4096, no spill. No old export from the sidecar is called.

Actual unit22077 uses captured640-token hidden FP8, skip F32, and stock877e weight/output. Two original executions release the full weight before two compact executions. All four655360B outputs match captured gold bit for bit, with FP8 nonfinite0 and256B canary unchanged. This proves one real matrix, not eight-key allocation or Frame timing. Driver-free counters are not residency peaks.

Private prepare_route.py emits a copied host. Only known block31..38 contract weights on the actual byte-edge consumer can compact. Cold NR_VIT_CONTRACT_COMPACT=1 requires stock and sidecar SHA, fixed processing1152/FAST/MP1/no experimental temporal/no graph, and no custom module selector. Missing sidecar/export and unknown paths retain original weights/functions. An existing legacy cache entry retains its original pointer and function. New pointers are tagged; the Run path uses the already cached new function only for those pointers, without new module loads, probes, hashes, or fences.

Final Frame CPU build31435 passed O2 using the existing NativeGameFrame benchmark and private headers, with -lbcrypt. NR0/1 selects both arms in one executable; exact memory diagnostics are outside performance windows. Full Frame/resource/performance evidence is pending the coordinator's gates. Raw weights, generated binaries, and replay output buffers stay outside git.
