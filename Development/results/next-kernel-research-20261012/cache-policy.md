# 缓存策略只读审：仅保留一个弱候选

基线：生产79599997。结论：可以保留“prefix只对长寿命skip0写出使用低重用TH”的单点候选，但**没有当前cache-miss/带宽/stall证据支持其必然有收益**。不是已经发现一个瓶颈。本轮没有编译、GPU实验、部署或提交。

## 具体位置与真实模块

当前43模块清单 `HIP/experiments/auto-timeline/measurement/results/aa-31627/modules-preflight.json` 锁定 `c32-wave1-fast.hsaco`：400496B，SHA `f46b8af25841a9878ce34544f4b3465f71da36fec9f08f48ad33b48f08c1ee52`。不能仅靠清单存在性认定加载：当前构造函数将c32_wave1交给FastTwin(...,true)，FAST1使用固定c32-wave1-fast stem，且MODE0无experimental temporal/900norm分支；对应上述f46。

本地同SHA原始模块只读反汇编了 `c32_wave1_prefix_b8d` 和 `c32_wave1_post_b8`，不是把新候选ISA当生产。

`HIP/hip_reference_network.h:591` 的prefix返回main/down两条边：main `New(n*8)` 按float计字节即 `W*H*32` FP8，1920×1152为70,778,880B=67.5MiB；down为其四分之一，即17,694,720B=16.875MiB。`RunGraph` 将 `pre.main` 保持为 `skip0`，最终post70才作为残差输入；prefix down立即交block1。`skip0` 的强引用持续到post70，不能假设它是可覆盖scratch。旧完整161调用记录是首prefix到末post的长跨度；这里只用它说明顺序，未据此伪造当前耗时。

源 `hip/wave_owned_c32.inc:529` 的完整tile分支把main每lane一次8B向量写出，8次覆盖main；down另外两次8B写出。实际prefix ISA有10处普通 `global_store_b64`，未显示非默认TH修饰；post有3处普通 `global_store_b32`。例如prefix `0x4F10C: EE06C07C 04000000 0000000A`，post `0x56EDC: EE06807C 01800000 0000005B`。这些是静态指令站点数，不是动态事务数。实施前仍须按arg4/arg5地址基追踪确定哪8处是main，**不能把全部10处改掉**。

最小候选只改prefix main的store hint为 `TH_STORE_NT`；down保原RT，所有加载、输出字节、向量宽度、数值顺序、scope及fence保原。理由只是main单次写入、远后继才读取，具有降低无效缓存保留优先级的可能。它仍有未来消费者，不是“不再读”的数据，也不能使用丢弃dirty语义的load-last-use来替代。

## TH语义与不选末端RGB的原因

AMD RDNA4 ISA §4.1、表14把TH定义为缓存保留优先级提示：RT默认，NT表示近/远缓存均不预期重用；NT_RT则近缓存NT、远缓存regular。它不是“保证绕L2”的开关，不能从名字推导省显存带宽、强制不分配或改变同步可见性。LLVM23语法也明确区分NT、NT_RT、RT_NT等，BYPASS另有scope限制。

- [AMD官方RDNA4 ISA，表13/14](https://www.amd.com/content/dam/amd/en/documents/radeon-tech-docs/instruction-set-architectures/rdna4-instruction-set-architecture.pdf)
- [LLVM23官方缓存修饰语法](https://releases.llvm.org/23.1.0/docs/AMDGPUModifierSyntax.html#th)

生产MP1的final-direct把post RGB直接写到bridge-owned sink（26,542,080B），接着由D3D neural转换/decoder读取；它不是长时间无人读取的纯废弃末端。故本轮**不把finalRGB设为优先NT对象**，也不重新打开已经默认有效的direct-output/DirectIO方案。

## 旧负账边界与最小验收

`failed-experiments.md` 的09-30 Infinity Cache/MRU scratch arena负项改变的是池分配复用顺序；本候选不改allocator或地址。10-01～03的decoder NT是N方向tile数特化，`DEC_F8W`是权重存储/数学路径，均不等于non-temporal store。prefix noise-cache负项改变额外噪声张量供数，本候选不新增缓存表/读写。没有据关键词把这些负项当TH策略已试，也没有声称因此TH一定值得采用。

若后续授权，只做一个新导出：限定prefix main stores。先审ISA只预期TH位变化、VGPR/LDS/private及scope不变，明确没有改down或同步；真实双输出main/down完整bytegold→全Frame0900/Auto计数→一轮当前相同生产路径短A/B。应同时保尾部回归和跨阶段缓存副作用：prefix单核快不代表全Frame快。若没有可分辨全Frame收益就止，不扫一套TH枚举寻正。

未知：实际写分配/eviction、MALL/L2命中、memory stall及跨kernel缓存驻留均未测得；当前Auto hostQPC时间线不能补这些证据。没有速度数字或FPS承诺。
