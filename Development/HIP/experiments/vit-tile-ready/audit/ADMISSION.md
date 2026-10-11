# Independent admission checklist

Source baseline: `30040d4c`, `hip/deep_fast.hip::vit_contract_blocked_body` and
`hip/vit_stream.inc::vit_stream_qkv_frag_bin_w5f8`.

The CPU geometry check is passed for 624/640/656 tokens. This is neither GPU
publication nor numeric/progress validation. For 640 tokens there are 640
producer groups, 40 counters and 768 five-wave consumer groups. Every tile
requires all sixteen 64-column producers; each live consumer wave reads all
1024 columns. A tail wave must not wait on an absent tile, but must still reach
the original uniform group barriers.

Required source/ISA gates before GPU:

- Original math, operand order, FP8 stores and AoS addresses remain unchanged.
- All producer lane stores complete before leader publication. Explicit group
  synchronization and agent-scope release are required; SIMD convergence alone
  is not the publication proof. Inspect generated waits/cache operations.
- Every producer counter update is an agent-scope acquire/release RMW. The
  consumer agent acquire observing sixteen must acquire the complete release
  sequence, rather than only one producer's stores.
- Ordered counter/diagnostic reset precedes both launches on every repeat.
  Inputs, outputs and counters stay alive through actual completion. No pool
  reuse or stale count sixteen is permitted.
- Consumer launch really clears the AQL barrier through the explicit any-order
  API. Producer dispatch order and finite resident wait occupancy must permit
  producer progress. No assumption of universal concurrent scheduling.
- Polling is bounded; wave results merge into a uniform group decision before
  original shared-memory barriers. Failure writes an explicit diagnostic and
  prevents numeric admission; no unready input read or silent fallback.

Actual unit gates: lock input/module/function/packed-weight identities; preserve
the independent ordered contract and QKV references; compare the complete
logical producer FP8 output and consumer three-plane FP8 output byte-for-byte,
reject FP8 NaNs, repeat with fresh reset and poison buffers. Record status,
counts, launch requested/effective/call count and timestamp evidence separately.
Numeric equality is not overlap proof; overlap is not a performance gain.

Status: candidate source/ISA, hardware numeric and forward-progress gates pending.

## Actual generated-source review

Reviewed `/home/lmxxf/work/dlss5-vit-tile-ready-build/candidate.hip`, SHA prefix
`619fe5ab`, with realtime `s_sendmsg_rtnl(131)` instrumentation. Source admission
has no identified hard block for the fixed 640-token pair: two producer barriers
surround all-lane release, leader counter updates are acq_rel; each live consumer
wave leader performs acquire loads, writes its failure slot, and a uniform group
barrier/decision precedes all original math. The original arithmetic is preserved.

Caller must reject any nonzero reuse gate, incorrect 4096/1024 contract shape,
illegal token count, missing reset, and any failed status. The wrapper would
otherwise publish after a shape-mismatched original body that did not write.
The finite one-million-poll bound is a diagnostic budget, not a guaranteed safe
forward-progress theorem or milliseconds. Watchdog remains required.

The producer timestamp is **before** the publication RMW, so it is a conservative
lower bound, not the exact publication instant. Consumer work-start is after the
uniform wait decision/acquire and before original weight/input work. Enter time
alone proves only possible spinning overlap. The realtime instruction and actual
agent cache/store waits still require compiled ISA review; GPU equality and
overlap remain pending.

## Compiled ISA review

The pulled `candidate.hsaco.s` was inspected at producer lines 98955--98995 and
consumer lines 99185--99415. Producer FP8 stores precede `s_wait_storecnt 0`,
then device-scope `global_atomic_add_u32` and completion wait. Consumer counter
loads use `scope:SCOPE_DEV`, load waits and `global_inv scope:SCOPE_DEV`; failed
slots merge after real `s_barrier_signal`/`s_barrier_wait`, with a uniform error
branch before the original work. An additional device invalidate precedes work.
Realtime is actually `s_sendmsg_rtn_b64 ... MSG_RTN_GET_REALTIME`, not a per-CU
cycle counter. This compiled gate is passed for the reviewed candidate; it does
not establish hardware overlap or guaranteed scheduling progress.

Initial pair caller review found the contract packed-weight extent stale at
4,198,400 bytes; actual is 16,781,312 (scale tail starts at 16,777,216). Main is
correcting it before launch. Requested a second independently reset any-order
run, since two ordered original references do not establish concurrent repeat.

## First hardware pair result

Main reports authoritative session `40675` exit 0 / lock released. The five
actual caller modes report full contract/QKV zero byte differences, zero FP8
NaNs, zero timeout status and all forty ready counters exactly sixteen.
Result-file manifest independently shows all five 655,360-byte contracts share
SHA `72f2dceb664db4cb962652231790e1fcffa3cd732b151ecada76b92ac1069c64`
and all five 1,966,080-byte QKV outputs share
`845725af3275ea6e820eb6f18db71dc72a1c6a7f71b63f889e028ed5977348d7`.
This audit checked the received manifest/log, not a second local raw-byte replay.

Independent CPU timestamp inspection found valid positive monotonic timestamps
and unique 640/768 group IDs. Ordered: zero consumer preparation markers precede
the final producer marker. Any-order repeats: 139 and 107 markers precede it
(enter markers 159/151). This proves preparation begins before the producer
tail; the marker precedes weight fetching and does not prove the first WMMA has
completed during that overlap. Main may move the marker for a separate diagnostic.
Instrumented single-pair event times are not an accepted performance comparison.

## First-MMA diagnostic admission

Reviewed the new source SHA prefix `41b73590` and actual
`math-diag/candidate.hsaco.s`: line 99608 computes the first FP8 WMMA into
`v[9:16]`; line 99613 performs a volatile system-scope store consuming `v9`;
line 99614 waits for the store, then line 99615 reads GPU global realtime.
Consequently the marker depends on a completed real matrix result, unlike the
discarded unused inline-assembly-input attempt. The temporary 32-bit diagnostic
value is overwritten by the 64-bit clock only after completion; arithmetic,
operand order and publication logic are unchanged. This finite fixed-640
diagnostic is admitted. Hardware result and uninstrumented speed remain pending.

Actual first-MMA diagnostic received: all five modes again report complete C/Q
zero byte differences, zero NaNs/timeouts/bad counters. Independently executing
the measurement parser on the two actual traces found respectively 36 and 157
consumer groups with a **completed first WMMA** before the final producer's
pre-publication marker (maximum conservative overlap 80/484 realtime ticks).
Thus real arithmetic overlap exists in this sample; this is not a speed result.

## Trace-off fair-screen decision

Reviewed trace-off source `d6fbb0a15ea956b823c5003911ca2836df064362de82ae52ebb2bc9eb3faee41`;
actual compiled ISA contains no realtime-message instruction. Fair `timing.cpp`
uses four A/B/B/A slots, ten warmup and twenty measured pairs each. Candidate
counter/status reset remains inside both GPU and wall windows. Both variants
perform the same two small validation D2H copies outside timing; each slot's
first/last complete C/Q outputs are compared with fixed references. The actual
`run_timing.ps1` checks fixture/executable hashes and complete sample counts.
This bounded screening source was admitted without further math variants.

Authoritative fair session `31969` exited zero; all eight actual edge checks are
zero-difference/finite. Root/measurement reported original GPU mean 0.070043 ms
versus candidate 0.095770 ms, about 36.7% slower; both candidate slots are slower
than either original slot. Decision: **STOP this candidate**. Do not promote,
run an APP benchmark, or infer a whole-frame gain from observed arithmetic
overlap. Production/game configurations are unchanged by this experiment.
