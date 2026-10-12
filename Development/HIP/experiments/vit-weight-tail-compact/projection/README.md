# Projection tail relocation (contract remains enabled)

Started only after contract acceptance3ca3fcb8. Native projection weights are a1MiB raw FP8 fragment matrix plus1024F32 scales originally at4MiB. Copying the live byte ranges yields1,052,672B, with scale float index1048576→262144. No FP8/F32 conversion or MMA/reduction/skip change; original template default and exports preserve old semantics.

COMGR57847 exited0/released, emptyopts/gfx1201. New sidecarSHA8cd0807f1364dfc4cc9cd13bdd96bca042fd2ab3db9e05e62d64d7762be15de6. Actual ABI56B, eightargs, WG/wave32, LDS0, VGPR120/SGPR14/no spills. Only the new bb_compactw export is called from this sidecar.

Actual unit92358 passed four complete2,621,440B F32 outputs against captured gold and the first original output, nonfinite0/canary0. AV and skip are both FP8; unlike contract, this output is F32. Old weight is freed before compact weight allocation. Exact storage proof addresses every1,048,576 matrix byte and copies the raw4096B tail; the maximum new read byte is1,052,671.

Paired private host adds independent projection pointer tags/cachedfunction over the accepted contract host. Only the actual bb consumer (byte-edge plus n64 projection selection) requests compact storage; b/h/bh/ordinary paths keep their old loader. Existing oldcache returns oldpointer with oldfunction, unknown/missingexport/customselector keeps oldroute. Coldload/SHA/probe precede any frame producer; Run adds no load/probe/hash/fence. Both Frame roles retain NR_VIT_CONTRACT_COMPACT=1; NR_VIT_PROJECTION_COMPACT=0/1 is the only arm difference. FinalFrame61932 O2 passed, audit source gates passed; fullFrame resource/timing evidence pending coordinator. No production source/game change.
