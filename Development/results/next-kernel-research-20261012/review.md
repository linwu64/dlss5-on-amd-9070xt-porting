# 独立审结论（2026-10-12）

基线生产 `79599997`。两项均 **PASS为可做单点有界实验的候选**，不是性能已证；优先V末barrier，缓存项更弱。本轮没有编译、GPU、部署、共享源码/WorkingPlan修改或提交，不增加第三项。

## 1. V-only末端rendezvous：依赖成立，待候选ISA门

核对真实joint模块 `da1b4ae9af3c1d2889f86e530b915971494ff2a58156a6abab2813dfb2d26014` 的 `vit_stream_qkv_frag_bin_w5f8` 与 `hip/vit_stream.inc:197–232`。`part=bid()/perpart` 仅依赖WGid与统一token数，五个wave走同分支。原ISA在 `0x94410` 判part2，仍于 `0x9443c/0x94448` 执行signal/wait，`0x9444c` 才跳过norm。V循环后无LDS复用，输出仅依赖本wave累加器；Q/K随后覆盖weight LDS，故其复用前barrier必须保留。

只允许把这一个末端rendezvous放入 `part<2`：loop内所有barrier、Q/K复用前barrier及raw写后/norm读前barrier、最后LDS/load/WMMA hazard等待均保持；`!live`波不能提前退出loop或Q/K同步。不能把源代码少一句当ISA安全证。官方LLVM源码 [`IntrinsicsAMDGPU.td`](https://github.com/llvm/llvm-project/blob/main/llvm/include/llvm/IR/IntrinsicsAMDGPU.td) 将裸barrier列为IntrNoMem/convergent，它本身不是内存fence；旧LLVM23裸barrier缺wait_dscnt负账仍适用，不能连WG_FENCE或必要wait一起删。

未找到同一V终段候选。旧V TR-load已经提前V加载并在QK下隐藏等待，不能重做；本项不改加载/布局/算术。下一门：候选ISA逐路径证明仅V免rendezvous、资源不退→实际640完整QKV重复byte/finite及尾wave依赖检查→一个短pair筛选；确有信号才当前Auto完整Frame单轮。无可辨收益即止，不扫展开/预取/屏障组合。

## 2. Prefix main-only NT store：后继和指令对象已确认，收益依据弱

核对生产 `f46b8af25841a9878ce34544f4b3465f71da36fec9f08f48ad33b48f08c1ee52` 的 `c32_wave1_prefix_b8d`。kernarg `0x20` 的 `s[36:37]` 是arg4 main，`0x28` 的 `s[38:39]` 是arg5 down。前八个b64 store（`0x4f10c,4f1c4,4f27c,4f334,4f3ec,4f4a4,4f584,4f5c0`）地址从main基址生成；最后两个 `0x4f92c/4f968` 从down基址生成，不能一起改。全tile写量分别是67.5MiB与16.875MiB@1920×1152。

`RunGraph` 将main留作强引用skip0直到post70才读；down立即供block1。本项只给前八个main store低重用TH，保持down、scope、向量宽度、值、wait与stream依赖。它仍有未来消费者，绝非可丢弃dirty数据。官方 [LLVM23 TH说明](https://releases.llvm.org/23.1.0/docs/AMDGPUModifierSyntax.html#th) 把NT列为temporal hint，BYPASS是另一值；不能称保证绕L2或必省带宽。无当前miss/驻留/stall证据，不能从67.5MiB推速度。

旧MRU池、noise-cache、decoder的N-tile特化不等于本项hint；也不借此重开地址skew/池扫描。下一门：仅这八个store的TH位变化、其他指令/资源/scope保持→真实main+down双输出完整gold→当前Auto全Frame单轮短A/B（含末post缓存副作用）。无稳定收益即止，不扫TH枚举。finalRGB立即被D3D读取，不作为本轮NT对象。

依据主体报告：[等待候选](wait-hiding.md)、[缓存候选](cache-policy.md)；旧负账见 `Development/failed-experiments.md` 的V TR-load、QKV/FFN预取、LLVM23 barrier修复、Infinity Cache条目。当前CPU host timeline不能证明GPU热点或缓存瓶颈。
