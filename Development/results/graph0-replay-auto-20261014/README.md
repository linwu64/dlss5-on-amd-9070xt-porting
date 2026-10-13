# ReplayAuto (161 Kernels + 1 Timed EventRecord = 162-Node Strong DAG): Gold & 3-Round ABBA Closure (STOP)

Date: 2026-10-14  
Experiment patches: `Development/HIP/experiments/graph0-replay-auto-20261006/`  
Binary (`graph0-replay-auto.exe`) SHA256: `70a61794cd7a5566e02792ba2b990064cbeb5974d960992bec285e96ae7b3c6a`  
Device: AMD Radeon RX 9070 XT (`gfx1201`), Driver `32.0.22029.9039` (`amdhip64_7.dll` ROCm 7.0.2 CLR)

## 1. Source Audit & ROCm 7.0.2 CLR Stream Capture Fix

The earlier CPU-only candidate (`cd0534bb`, `exe_sha256=279984df...`) enforced a strict 162-node Kahn topological gate (`n == eager.size() + 1 == 162`, exactly 1 `hipGraphNodeTypeEventRecord` (`type=7`) bound to `pulse_lease.LabActiveSingleHandle()`, positioned at `position=24` immediately after `mh_fast:mh_pool_project_group_c256` and immediately before `c512_m32_deep:split_ffn_one_w2f8`), but called ordinary `hipEventRecord(handle, *stream)` (`flags=0`) during `hipStreamBeginCapture`.

On first GPU execution (`unfixed-cd0534bb-capture-fail/stderr.log`), `hipStreamEndCapture` succeeded and `pulse_ops.record_ok` incremented (`capture_record_calls=1`), but `hipGraphGetNodes` returned `n=161` (`REPLAY_AUTO_NATIVE_FAILURE reason=APP graph dynamic node count`). Root cause in ROCm 7.0.2 CLR (`hip_event.cpp:365-413`):
1. `hipEventRecord(event, stream)` calls `ihipEventRecord(event, stream, flags=0)`. During stream capture, ROCm 7.0.2 CLR only creates a `GraphEventRecordNode` when `flags == hipEventRecordExternal` (`1`); for default `flags == 0`, it records the event on the underlying stream and returns `hipSuccess` without adding any node to the capturing graph.
2. Calling `hipEventRecordWithFlags(event, stream, hipEventRecordExternal=1)` cannot be used directly on ROCm 7.0.2 because `hip_event.cpp:406` declares `amd::GraphNode* pGraphNode;` uninitialized before `pGraph->addEventRecordNode(&pGraphNode, ...)`, which fails `if (node == nullptr || *node != nullptr) return hipErrorInvalidValue;` inside `hip_graph_internal.cpp:964` whenever stack memory is non-zero.

### Fix (`submit_pulse_hip.h`, `submit_pulse.h`, `hip_reference_network.h`)
During stream capture (`graph_capturing == true`), `SubmitPulseLease::Record(true)` invokes `HipSubmitPulseOps::record_capture(handle)`:
1. Calls `hipEventRecord(handle, *stream)` to preserve host/runtime event state.
2. Queries the active capture graph and single tail dependency via `hipStreamGetCaptureInfo_v2(*stream, &cstatus, nullptr, &cgraph, &deps, &ndeps)` (`cstatus == 1 && ndeps == 1`).
3. Explicitly inserts the `GraphEventRecordNode` (`type=7`) bound to `handle` via `hipGraphAddEventRecordNode(&evNode, cgraph, deps, 1, handle)` (passing zero-initialized `Handle evNode{}`).
4. Updates the stream capture frontier to `{evNode}` via `hipStreamUpdateCaptureDependencies(*stream, &evNode, 1, hipStreamSetCaptureDependencies=1u)` so the next kernel (`c512_m32_deep:split_ffn_one_w2f8`) depends strictly on `evNode`.

## 2. 12-Frame HDR Residual Sequence=2 Gold Verification (`PASS`)

Scope: `1920x1152`, `F=1`, `MP=1`, `PRED=1` (inactive at `MP=1`), `AE=0`, `seed=0`, `history=0` (`reset=true`), `PDL=0`, `NET=0`, `overlap=0`, `DLSS5_RESIDUAL_SEQUENCE=2` (12 frames).

- **DAG & Event Ownership (`gold-replay/stderr.log`)**:
  - `REPLAY_AUTO_EXPORT GetEvent=00007ffc3021a500 AddEventNode=00007ffc302124e0 CaptureInfoV2=00007ffc302957b0 UpdateDeps=00007ffc3029a9f0 owned_event=0000028044ab8500`
  - `REPLAY_AUTO_EVENT position=24 after_down_fn=0000028014fc8e60 owned_event=0000028044ab8500`
  - `REPLAY_AUTO_EVENT next_C512_fn=00000280448a5b50`
  - `APP_GRAPH_MODE captured nodes=162 edges=161 event_record_nodes=1 external_interop_nodes=0 opt_graph=0`
- **Counter & Lifecycle Parity**:
  - `EagerAuto` (`gold-eager/stderr.log`): `frames=12 warm=4 capture_record_calls=0 graph_launch_api_calls=0 host_RecordAccepted=15 expected_host_Record=15 valid=1` (`create=1 create_ok=1 record=15 record_ok=15 destroy=1 destroy_ok=1 drain=1 site_visits=15 accepted=15 reject_mask=0`).
  - `ReplayAuto` (`gold-replay/stderr.log`): `frames=12 warm=4 capture_record_calls=1 graph_launch_api_calls=12 host_RecordAccepted=5 expected_host_Record=5 valid=1`, `APP_GRAPH_CLOSE before_lease_destroy=1 replay_calls=12` (`create=1 create_ok=1 record=5 record_ok=5 destroy=1 destroy_ok=1 drain=1 site_visits=5 accepted=5 reject_mask=0`).
- **Bitwise Accuracy (`gold2-hashes.json`)**:
  - All 12 `.f16` outputs (`out-f00.f16` .. `out-f11.f16`) are 100% finite (`nan_inf=0`) and bit-for-bit identical (`0 bit-diff`, matching SHA256s) between `EagerAuto` and `ReplayAuto`.

## 3. 3-Round 4-Slot Interleaved ABBA Performance (`STOP`)

Protocol: `A1 (EagerAuto) -> B1 (ReplayAuto) -> B2 (ReplayAuto) -> A2 (EagerAuto)`, 160 frames/slot, discard first 80, measure 80 steady frames (`160 frames/arm/round`, `480 frames/arm` across 3 rounds), `edges_only=1`, `NET0`, `DLSS5_SUBMIT_PULSE=2`, `DLSS5_RESIDUAL_SEQUENCE=2`, single process per slot under `D:\DLSSNR-Lab\gpu.lock`.

| Round | EagerAuto Mean (A1 / A2) | ReplayAuto Mean (B1 / B2) | $\Delta$ Mean (`Replay - Eager`) | EagerAuto p99 | ReplayAuto p99 | $\Delta$ p99 (`Replay - Eager`) | Drift (Control / Candidate Mean) | Round Gate |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Round 1** | `9.509006 ms` (`9.5031` / `9.5149`) | `9.491825 ms` (`9.4832` / `9.5004`) | `-0.017181 ms` (`-17.18 µs`) | `9.683050 ms` | `9.683010 ms` | `-0.000040 ms` (`-0.04 µs`) | `+11.84 µs` / `+17.20 µs` | Noise-floor |
| **Round 2** | `9.553869 ms` (`9.5383` / `9.5695`) | `9.518381 ms` (`9.4921` / `9.5447`) | `-0.035488 ms` (`-35.49 µs`) | `9.735740 ms` | `9.734000 ms` | `-0.001740 ms` (`-1.74 µs`) | `+31.21 µs` / `+52.56 µs` | Non-separable (`B2 > A1`) |
| **Round 3** | `9.561094 ms` (`9.5635` / `9.5587`) | `9.562006 ms` (`9.5508` / `9.5732`) | `+0.000913 ms` (`+0.91 µs`) | `9.732920 ms` | `9.761560 ms` | `+0.028640 ms` (`+28.64 µs`) | `-4.84 µs` / `+22.34 µs` | **STOP** (mean & p99 regress) |
| **3-Round Pooled (480f/arm)** | `9.541323 ms` | `9.524071 ms` | **`-0.017252 ms` (`-17.25 µs`, `-0.18%`)** | `9.732100 ms` | `9.736100 ms` | **`+0.004000 ms` (`+4.00 µs`, `+0.04%`)** | — | **FINAL STOP** |

## 4. Physical Mechanism & Conclusion

1. **Why 162-node `ReplayAuto` is ~17 µs faster on mean than 161-node `ReplayOff` (`+38 µs` vs `EagerAuto` in `67f988c0`), yet still provides zero net win over `EagerAuto`**:
   - Embedding the timed `EventRecord` node at `position=24` (`C256Down -> C512 first FFN`) restores the intra-frame command-processor barrier/flush pulse inside the graph replay stream, eliminating the `+38 µs` regression that unpulsed `ReplayOff` suffered relative to `EagerAuto`.
   - However, on RDNA4 (`gfx1201`) with ROCm 7.0.2 (`amdhip64_7.dll`), `hipGraphLaunch` does **not** compile the 161 kernels + 1 event node into a single GPU-resident command buffer; the runtime still iterates through the instantiated node list on the host and dispatches AQL packets per node (`capture_and_DAG_ms ≈ 3.45 ms`, `instantiate_ms ≈ 1.43 ms`), while adding graph-exec launch wrapper overhead that slightly degrades tail latency (`pooled Δp99 = +4.00 µs`, Round 3 `Δp99 = +28.64 µs`).
2. **Final Verdict**: **STOP**. The `ReplayAuto` 162-node strong-DAG candidate is numerically and structurally proven on GPU (`12/12` gold 0 bit-diff), and the hipGraph family (`opt.graph=1`, `graph0` same-work, `EagerAuto vs ReplayOff`, and `EagerAuto vs ReplayAuto 162-node`) is now **completely closed** on RX 9070 XT. Production remains on `EagerAuto` (`DLSS5_SUBMIT_PULSE=2`, `opt.graph=0`).
