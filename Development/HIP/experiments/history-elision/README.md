# Stage 1: explicit never-history bridge sessions

Baseline ec0a2e99 includes accepted compact ViT expand weights. NativeHipNetwork has an explicit caller_never_history capability defaulting false. Only NativeGameFrame with MODE0, no temporal_config, null final temporal RGB and false experimental state passes it true; the wrapper also rejects nonempty fast-history row or temporal/experimental inputs. Public bridge callers remain unknown and allocate history. DirectHistory/PostAuxiliary/experimental Create conflict, and all temporal recording/enqueue entrances fail closed; no lazy allocation.

Memory report uses actual resource widths, per-bridge creations/imports and pool hits. Old shared-pool residency is not freed by this change. Fresh-process comparison must distinguish per-bridge demand from process residency; 1920×1152 has a 35,389,440-byte logical history resource. No FPS benefit is assumed.

Final source compiled through the formal O2 HIP addon build (66039 exit0). CPU-only empty-resource/explicit conflict fixture passed nine rejection paths; receipts in results/. Actual resource, same-frame numerical and short timing gates remain pending. No stage 2/3 work.

## Actual decision

Stage-1 gold 43364 passed all three frames with raw SHA0900e489…, Auto3 and exact resource widths: baseline history35,389,440 bytes, candidate0, fresh bridge created2/imported2/poolhits0. ABBA36250 passed all eight gold endpoints and unchanged43 modules. Mean wall difference +3.596 µs was below control drift26.392 µs: no reliable performance change. Accepted for33.75MiB less per-session resource demand in the strict supported case; old shared-pool residency is outside that claim. Main decision checkpoint5ebd71dd.
