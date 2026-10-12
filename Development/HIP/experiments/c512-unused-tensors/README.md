# Stage 2: C512 unused temporary requests

Baseline 5ebd71dd includes accepted compact ViT weights and stage-1 explicit never-history sessions. CompactC512Body previously requested mixed and contract F32 tensors even when one-kernel FFN branches never consumed them. This candidate moves only those two New requests into the existing split-mix + split-FFN fallback. All Run expressions, pointer arguments, branch priority, contract8 allocation, tensor reset points and pool policy remain unchanged.

At 1920×1152, n=2160: each removed fast-path request is 4,423,680 bytes (4.21875 MiB), combined 8.4375 MiB logical simultaneous requests. Pool reuse can make net residency savings smaller or zero; actual pool/allocated measurements are pending. This is not an FPS prediction. Missing fused/one-kernel exports still select the unchanged two-kernel fallback, now explicitly allocating its outputs before use. No stage-3 changes.
