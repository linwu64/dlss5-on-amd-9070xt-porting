# Auto2 host timeline: minimal independent measurement contract

Scope: current full NativeGameFrame, production Auto2, MP1/FAST1/1152/Style1/seed0/history0, current modules/weights and existing frame completion boundary. This is a diagnostic of the existing execution, not a new optimization. MODE3, driver changes and game installation are outside scope.

## What can be observed without adding GPU work

Use one preallocated host record array and QPC. Keep the existing wall timer in both arms. Additional marks exist only with the private measurement flag. Save records after the complete run, not per frame. Do not add event queries, HIP/D3D events, queue submits, semaphore operations, fences, flushes, profiler reads, per-dispatch logs or per-frame allocations.

Record CPU boundaries around producer list recording/submission; original D3D Signal and HIP external-wait enqueue; Network::Enqueue host graph construction/launch submission; existing Auto event Record call; HIP external-signal enqueue and D3D queue-Wait enqueue; consumer recording/submission; and the caller's existing completion wait. Distinguish ordinary API return from actual fence completion. The queue-Wait and external-wait call durations describe host API work, not GPU wait duration. Nested host intervals must not be summed as disjoint work.

Recommended exported schema is `frame,mark,qpc_ticks` plus a JSON QPC frequency and exact mark-site/source identity. A wide schema with explicit `_begin/_end` ticks is equivalent. Preserve raw integer ticks. No GPU timestamps are implied by QPC.

## Existing facilities and limitations

- `src/native_game_frame.h` GAME_PROBE inserts GPU timestamp queries and explicitly Flushes each frame; it is not the low-disturbance production timeline.
- `experiments/network-timeline/trace-public.inc` creates/records HIP event pairs for each dispatch, then exports durations. The event commands can change pacing/overlap. Do not reuse its inter-event gaps as production idle proof.
- `src/native_game_submission.h` distinguishes deferred ring-slot waits and synchronous completion waits. Label each actual route explicitly rather than naming all Submit duration a GPU execution duration.
- Auto uses the existing submission pulse event; measuring its host call does not add another event. Preserve its requested/accepted/record counts and actual PDL calls.

Without a validated external GPU schedule trace or calibrated same-clock GPU execution markers, **GPU kernel execution, idle gaps, and overlap remain unobservable**. Never subtract CPU enqueue duration from Frame wall and call the remainder GPU work/idle. Never subtract unrelated asynchronous HIP and D3D elapsed intervals to attribute a gap. A CPU fence wait may overlap queued execution, driver work or other queue work; its duration is not idle duration.

## One bounded A/A disturbance screen

Use the same executable and immutable assets/modules, private flag0/1 only. Four fresh processes in order0,1,1,0, 320 frames each, discard80;480 steady samples per arm. Source/hash and first/last full HDR output are locked; all four Auto320/actual PDL counters and frame geometry must match. Preserve first-run failures; do not rerun to make the perturbation disappear.

The off arm must execute no additional QPC marks or diagnostic memory writes; both arms retain the same original wall timer and existing outside-window edge checks. Cold allocations, module loading, diagnostic export and memory reporting are outside the measured frame interval. Actual mark counts/source sites are frozen before the run.

Report per-slot and pooled mean/median/SD/p95/p99/max, mark-on minus mark-off, and A2−A1/B2−B1 drift. If both marked slots lie outside both unmarked slots in the same slower direction and the mean effect exceeds control drift, the diagnostic is detectably intrusive: stop causal GPU attribution. A similar tail worsening is retained, never averaged away. Otherwise say only “no disturbance resolved by this short screen,” not zero overhead or formal equivalence. With480 samples per arm, p99 is represented by roughly five tail observations; it is descriptive, not a certified tail bound.

The first report may identify long CPU API calls or completion waits. It cannot identify GPU bubbles. If external schedule tracing is unavailable, that is a valid explicit result; do not escalate to heavy tracing or alter production pacing without a separate decision.
