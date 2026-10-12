# Waiting research — one bounded candidate (2026-10-12)

Read-only research on production79599997; no build, GPU execution, deployment or product/WorkingPlan edits. Current host timing does not identify GPU hotspots, so no percentage or expected speedup is assigned.

## Candidate: skip only V's terminal workgroup rendezvous

Actual active function `vit_stream_qkv_frag_bin_w5f8`, current jointmodule SHA256 `da1b4ae9af3c1d2889f86e530b915971494ff2a58156a6abab2813dfb2d26014`. The frozen module is `/home/lmxxf/work/dlss5-resource-followups-build/joint-vit-tail/compiled/joint-vit-stream-fast.hsaco`; its43-file identity is bound by the completed Auto host-timing runs. The host's byte-edge eligibility and Run selection choose this export in the validated MODE0/1152/640 profile. Source: [vit_stream.inc](../../../hip/vit_stream.inc), lines197–232; eligibility: [hip_reference_network.h](../../HIP/hip_reference_network.h), line842.

The K-loop already double-buffers weights and fetches the next chunk before currentWMMA work (lines204–217). Do not rebrand this as a new softwarepipeline. After that loop, line222 executes a fullWG barrier for Q, K **and V**. Only Q/K then overwrite the old weightLDS with their normalization tile (lines225–228); V skips all subsequentLDS work and converts its own register accumulators directly to disjoint globalbytes (line232).

Read-only LLVM23 disassembly of the actual module confirms this is not already optimized away:

- `0x94410`: `s_cmp_eq_u32 s13,2` (V part classification).
- `0x9443c` / `0x94448`: unconditional `s_barrier_signal -1` / `s_barrier_wait 0xffff`.
- `0x9444c`: only **after** the rendezvous, the V path skips Q/K normalization.
- Q/K rawstores have their own real `s_wait_dscnt0` plus barrier at `0x944d8..0x944e0` before normalization reads.

Dependency argument: `part=bid()/perpart` is workgroup-uniform, including all fivewaves. For Q/K, the terminal barrier must remain: a fastwave must not overwrite weightLDS still being read by a slowwave. For V, no later LDSwriter/reuser exists, and eachwave's output depends only on its completed accumulator; no crosswave result is consumed. Thus the **source-level** idea is to place that one terminal rendezvous within `part<2`, with no early per-wave return and no changes to loads, accumulation, quantization, layout or instruction-level memory/hazard waits. NewISA would still require review; this is not a claim to delete waitcnt or replace memory completion with a weaker barrier. Independent audit agrees the WG-uniform V dependency case, but specifically requires all K-loop barriers, Q/K reuse/norm barriers and existing load/DS/WMMA hazard waits to remain. Inactive tailwaves must reach the original final live-test location; they must not return before a remaining WG barrier. The prior LLVM bare-barrier missing-wait failure is directly relevant to this validation, despite not being the same optimization candidate.

## Difference from negative history / value judgment

[failed-experiments](../../failed-experiments.md) covers VTR AV-load timing, column/AoS layouts, tile-ready crossdispatch protocol, QKV prefetch/deep rings, MH batchnorm/barrier rewrites and C32 local synchronization. Those alter supply, layout, buffering, registerpressure or different kernels. This candidate changes none of those: it removes only a final crosswave rendezvous from the V workgroups that never reuse LDS. No matching candidate was found in the audited ledger; absence is not exhaustive proof of novelty.

At640tokens there are256V groups among768groups perQKV dispatch, eight such dispatches perFrame. These counts **do not convert to savedtime**. Waves may already arrive together, a uniformbranch may cost more than the barrier, or generated allocation/scheduling may regress. A prior C128 emptybarrier test is not a bound for this dependent fivewave kernel. Priority is modest: there is a precise dependency case, but no evidence that this rendezvous materially limits completeFrame time.

If separately authorized later: one privateexport with the single uniform conditional; first confirm the intended V-only ISA difference and unchanged waits/resources, then actual640 fullQKV byte/finite gold (plus source-only tail-wave uniformity audit), and only a promising boundedpair screen justifies currentAuto completeFrame ABBA. Stop at correctness failure, unexpected resource changes or no stable benefit; no sweep, VTR retry or new profiling infrastructure. This round did none of these experiments.
