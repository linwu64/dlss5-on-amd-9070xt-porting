# Bound and compact: bounded optimization work

Production plan committed first: b93cc043, based on failed ledger967df5a3. All implementation lives on persistent branch bound-and-compact; no production defaults/game payload changes.

| Work | Owner / private path | Gate before GPU |
|---|---|---|
| A C32 upper score clamp | ../c32-score-nohi | Actual stock ISA and every admitted weight identity; rigorous bound including actual normalization, half-square and FP8 rounding; only certified layers may select a twin |
| B packed weight capacity | ../packed-weight-compact | Actual allocation/consumer/alias map; first no-tail ViT expand4096×1024 only; all4,194,304 original packed bytes unchanged, ordinary smaller allocation |

Common integration requirements: original NativeGameFrame/HDR caller, current effective production Auto/PDL policy, source/executable/module/flags/input/weights identities. Pure-NN/units only establish numerical or screening scope. After an actual unit gate, verify fullNN and Frame before any performance conclusion. Necessary protocol/memory costs belong inside the chosen measurement; cold creation/upload and diagnostic reports remain explicitly outside steady timing. Report mean/tail/drift and resource scope, not inferred FPS.

GPU queue is exclusively coordinated by math. `status.ps1` is read-only preflight evidence, not permission to skip a fresh guard at dispatch time. Every RTC/device case must own atomic gpu.lock, check game/RTC and >=100GB disk, poll game every15s, enforce a bounded owned-PID timeout and save actual terminal. Unknown/timeout cases are never silently restarted. All CPU artifacts are persistent; owners checkpoint their private directories without shared-header edits.

Current entry references: stock c32-wave1-fast f46b8af25841a9878ce34544f4b3465f71da36fec9f08f48ad33b48f08c1ee52 at /home/lmxxf/work/dlss5-dx12-artifacts/c32-family-20261010/; original full161 resource/dispatch ledger at /home/lmxxf/work/dlss5-dx12-artifacts/full-graph-50843/. These are provenance inputs, not a substitute for each new case's actual identity checks. Larger raw assets remain outsidegit. See PROGRESS.md for actual admission and queue state.
