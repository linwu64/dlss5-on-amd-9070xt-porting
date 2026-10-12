# Stage 2: C512 unused temporary requests

Baseline 5ebd71dd includes accepted compact ViT weights and stage-1 explicit never-history sessions. CompactC512Body previously requested mixed and contract F32 tensors even when one-kernel FFN branches never consumed them. This candidate moves only those two New requests into the existing split-mix + split-FFN fallback. All Run expressions, pointer arguments, branch priority, contract8 allocation, tensor reset points and pool policy remain unchanged.

At 1920×1152, n=2160: each removed fast-path request is 4,423,680 bytes (4.21875 MiB), combined 8.4375 MiB logical simultaneous requests. Pool reuse can make net residency savings smaller or zero; actual pool/allocated measurements are pending. This is not an FPS prediction. Missing fused/one-kernel exports still select the unchanged two-kernel fallback, now explicitly allocating its outputs before use. No stage-3 changes.

## Actual result and decision: STOP

Actual full-Frame gold26032 exited0 and released the lock: 48 CompactC512Body calls, fallback0, all three raw frames SHA0900e489… and Auto3 passed. Independent resource accounting found pool bytes290,571,128→292,742,008, **+2,170,880 bytes**; driver free memory improved only64KiB. Removing two logical requests did not reduce net residency, so the resource gate failed. No performance run or pool-layout variants were started.

The shared header has been restored byte-for-byte to5ebd71dd, preserving accepted compact ViT weights and stage1. The unsuccessful source change is retained in candidate.patch. Stage3 is a separate task.
