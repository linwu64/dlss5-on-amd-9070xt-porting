# ViT contract → QKV tile-ready bounded experiment

Base: production 30040d4c81d486d66b588da0dcb5ac67a67b5c41; branch vit-tile-ready.
Status: CPU implementation; no GPU launched, no candidate accepted.

First gate: real 640-token pair, identical original math/AoS/weights; explicit any-order consumer launch, bounded acquire wait, timestamps proving overlap and producer progress. Original independent HIP pair is reference. Compare full contract and QKV byte/finite outputs. Fail/timeout stops this case; preserve logs.

Producer: original 32-thread contract WG writes 16 tokens ×64 columns. Agent-release completion per WG contributes one of 16 column blocks to a token-tile counter. Consumer: existing five-wave QKV WG waits for each live wave's 16-token tile, agent acquire after publication, then uniform WG barrier before original weight/MMA math. No butterfly stores or precision changes.

Fresh flags and owned diagnostics per pair; no pooled reuse until fence/sync. Tail guard requires a multiple-of-16 token count not divisible by80. Waiting consumers must not prevent producer completion; bounded failure and device/game watchdog required.

Only if pair correctness and measured scheduling evidence show potential: short same-production whole-frame ABBA. No deployment/push/driver changes. Pair timings are not whole-network performance.
