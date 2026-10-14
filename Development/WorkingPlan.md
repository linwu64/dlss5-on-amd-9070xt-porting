# 当前工作计划

更新：2026-10-14。**正式0.42已于10月13日完成三包交付，用户已提供网盘下载入口。** 载荷源码 `456b7e16`，构建/验收归档 `88472e96`；发布与哈希见 [0.42记录](releases/0.42/README.md)，功能与设置见 [使用说明](../0.42-更新与使用说明.md)。2026-10-14 补完留置 `ReplayAuto`（161 kernel + 1 timed EventRecord = 162 节点强 DAG）的 ROCm 7.0.2 CLR 捕获修复、12 帧 gold 0-diff 与 3 轮 4-slot ABBA（pooled Δmean=−17.25µs、Δp99=+4.00µs，R3 均值/p99 双退步，结论 **STOP**，见 [ReplayAuto结题报告](results/graph0-replay-auto-20261014/README.md)），hipGraph 全家桶在 RX 9070 XT 上彻底封板，生产维持 `EagerAuto`（`DLSS5_SUBMIT_PULSE=2, opt.graph=0`）。同日完成 **C512 W16（16B `global_load_b128` 权重分块，`HIP_C512_W16=2` 默认开启）**，原地复用 `@proj-frag`/`@qkv-frag` 实现 **0 字节额外显存**，1920×1152 Gold 逐位一致（`0900E489...`），独立 NN 微基准 `-0.088 ms`、完整 Frame 3 轮 4-slot ABBA（960f/arm）`u4` 6/6 对偶全负、pooled Δmean=`-16.7 µs` / Δmedian=`-14.5 µs` / Δp90=`-17.0 µs`（`u2` Δmean=`-14.8 µs` / Δp90=`-27.0 µs` / Δp99=`-16.0 µs`），已合入主线并同步更新 `gfx1200`/`gfx1201` 模块（见 [C512 W16 报告](results/c512-w16-20261014/README.md)）；随后反汇编 `c512-m32-deep` 发现 `split_ffn_one_w2f8` 的 Mix/Expand/Contract 三个权重区仍为未分块 row-major E4M3（每 wave 256 条跨 512B/64B/256B 非合并 `global_load_b64`），完成 **C512 Split-FFN W16（`split_ffn_one_w2f8_w16`，`HIP_C512_FFN_W16=1` 默认开启）**，原地复用 `@split-mix-fp8` 零额外显存将 256 条跨步 `global_load_b64` 替换为 128 条 100% 合并 `global_load_b128`（124 VGPR，0 spill），1920×1152 Gold 逐位一致（`0900E489...`），在已开启 `HIP_C512_W16=2` 的基线上完整 Frame 3 轮 4-slot ABBA（960f/arm）3/3 全胜（`-134.8 / -131.8 / -127.2 µs`），pooled mean `9.5926 → 9.4614 ms`（**`-0.1312 ms` / `-131.2 µs`，median `-0.1345 ms`**，最快轮 `9.4126 ms`，见 [C512 Split-FFN W16 报告](results/c512-ffn-w16-20261014/README.md)）；紧接着对 C32 `wave1` 完成 **C32 Wave1 W16（`c32_wave1_*_w16`，`HIP_C32_W16=1` 默认开启）**，原地复用 `@c32fp8` 零额外显存将未分块 row-major 的 88 条 `global_load_b64` 权重与对角加载替换为 30 条 100% 合并 `global_load_b128`（136 VGPR，0 spill），1920×1152 Gold 逐位一致（`0900E489...`），在已开启 `HIP_C512_W16=2` 与 `HIP_C512_FFN_W16=1` 的基线上完整 Frame 3 轮 4-slot ABBA（960f/arm）3/3 全胜（`-27.4 / -19.9 / -24.6 µs`），pooled mean `9.4717 → 9.4477 ms`（**`-0.0240 ms` / `-24.0 µs`，median `-0.0328 ms`**，单槽 median 最低 `9.3900 ms`，见 [C32 Wave1 W16 报告](results/c32-w16-20261014/README.md)）；随后定位出此前 ViT `compactw` W16 退步真因是 Clang 完全展开外层 `part=0..3` / `p=0..3` 分片循环导致 VGPR 暴涨至 `251`/`220`，通过外层循环 `_Pragma("clang loop unroll(disable)")` + 内层 `_Pragma("unroll 2")` 完成 **ViT 核心三算子 W16（`vit_expand_blocked_fp8_frag_bytein_w16`、`vit_stream_contract_frag_bout_compactw_w16`、`vit_stream_project_n64_bb_compactw_w16`，`HIP_VIT_W16=7` 默认开启）**，原地复用 `@vit-frag@compact-*` 零额外显存将 128/256/128 条 `global_load_b64` 替换为 64/128/64 条合并 `global_load_b128`，并将 Contract VGPR 由 **`211 → 115`（`-96 VGPR`，Occupancy `6 → 8 waves/SIMD`）**、Projection VGPR 由 **`190 → 114`（`-76 VGPR`，Occupancy `6 → 10 waves/SIMD`）**，1920×1152 四模式 Gold 逐位一致（`0900E489...`），在已开启 `HIP_C512_W16=2`、`HIP_C512_FFN_W16=1`、`HIP_C32_W16=1` 的基线上完整 Frame 3 轮 4-slot ABBA（960f/arm）3/3 全胜（`-47.8 / -59.3 / -62.9 µs`），pooled mean `9.4732 → 9.4166 ms`（**`-0.0566 ms` / `-56.6 µs`，median `-0.0665 ms`**，单槽 median 最低 **`9.3620 ms`**，今日三场 W16 战役累计净降 **`-0.2118 ms` mean / `-0.2338 ms` median**，见 [ViT W16 报告](results/vit-w16-20261014/README.md)）；紧接着完成 **ISA Epilogue 去分支与 `v_movrels` 清理（`isa-epilogue-clean-20261014`）**，统一将 C512 Pool/Attention Project、Deep Split Projection、C512 QKV Attention、C256 Swin Wave2、C32 Wave1 尾部的带分支 FP8 clamp 替换为无分支 `__builtin_amdgcn_fmed3f(x + 0.f, -448.f, 448.f)` 并重排循环消除 `v_movrels_b32`（`mh_pool_project_group_body` `v_movrels_b32: 18 → 0`、`s_cbranch: 102 → 5`，`mh_attention_project_frag_c512_w16_body` `v_movrels_b32: 4 → 0`、`s_cbranch: 58 → 17`），更新 18 个 `gfx1200`/`gfx1201` `.hsaco` 模块，1920×1152 Gold 逐位一致（`0900E489...`），在已开启全部四项 W16 的基线上完整 Frame 3 轮 4-slot ABBA（960f/arm）3/3 全胜（`-148.4 / -130.8 / -159.3 µs`，6/6 对偶全负），pooled mean **`9.4263 → 9.2801 ms`（`-0.1462 ms` / `-146.2 µs`，`-1.55%`，median `9.4190 → 9.2755 ms` / `-0.1435 ms`）**，单槽最快 **`9.2388 ms`**（见 [ISA Epilogue 报告](results/isa-epilogue-clean-20261014/README.md)）；随后完成 **二轮全网 ISA 病灶审计与清理（`isa-audit2-20261014`）**，将 `deep_fast.hip` 的 `F(x)` 与 `vit_contract_F_byte(x)`、`wave_owned_mh.inc` 的 `w2_z`/`w2_up_F`/`w2_skip_byte`、`wave_owned_c32.inc` 的 `cw_up_F` 统一替换为 `fmed3f(x + 0.f, -448.f, 448.f)`（`vit_stream_contract_frag_bout_compactw_w16` `-109` 条、`vit_stream_project_n64_bb_compactw_w16` `-94` 条、`c64_wave2_up_lb_sh` `-229` 条且 `v_cndmask_b32: 175 → 47`），并将 `c32_wave1_post*` 的 8 次 `ds_load_u16` 合并为 1 条 `ds_load_b128`（`s_wait_dscnt: 14 → 7`）、`c32_wave1_finish*` 的 `Crop` 下采样分支统一纳入 `ds_load_b128` + `global_store_b128` 向量化与存储谓词外提（`c32_wave1_finish_b8_w16` `2116 → 1589` `-527` 条、`c32_wave1_finish_dcrop_b8_w16` `2557 → 1621` `-936` 条、`c32_wave1_finish_dcrop_b8d_w16` `2203 → 1591` `-612` 条），同时实测证伪了用 `v_cndmask_b32` 选择树替代 `wave_owned_c32/mh` 中 uniform SGPR `m0` `v_movrel` 的伪优化（会打断 VOPD 并令 `c32_wave1_chain_w16` 膨胀 `+108` 条指令），1920×1152 Gold 逐位一致（`0900E489...`），3 轮 4-slot ABBA（960f/arm，5/6 对偶为负）pooled mean `9.2894 → 9.2838 ms`（**`-5.6 µs` mean / `-9.5 µs` median / `-7.0 µs` p90**，见 [ISA Audit2 报告](results/isa-audit2-20261014/README.md)）；紧接着完成 **ViT 块间字节流直连与 `vit-stream` QKV Epilogue 清理（`vit-inter-byte-20261014`，`HIP_VIT_INTER_BYTE=1` 默认开启）**，导出 `vit_stream_project_n64_bb_bout_compactw_w16` 与 `vit_stream_contract_frag_bstream_bout_compactw_w16`，将 ViT blocks `31..37` 的投影输出与 blocks `32..38` 的残差输入直接由 4B FP32 改为 1B E4M3 字节流直连（消除每帧 7 次独立 `vit_pack_input` 发射使全网每帧总发射数由 `161 → 154`，消除每帧 `49.28 MB` 全局显存往返流量，且在 `Gather()` 后立即 `input.Reset()` 保持 `pool_MiB=277.1 (27 tensors)` **0 字节额外显存**），同时为 `vit-stream-fast`/`vit-stream` 补齐 `'HIP_BYTE_F_ADD0 1'` 并将 `vit_stream_qkv_frag_bin_w5f8` 的 `if (part < 2)` 归一化外提（VALU `233 → 168` `-65` 条、`v_cvt` `48 → 16` `-32` 条），1920×1152 Gold 逐位一致（`0900E489...`），完整 Frame 3 轮 4-slot ABBA（960f/arm）3/3 轮全胜、6/6 对偶全负（`-179.6 / -174.5 / -157.1 µs`），pooled mean **`9.2807 → 9.1103 ms`（`-0.1704 ms` / `-170.4 µs`，`-1.84%`，median `9.2735 → 9.1124 ms` / `-0.1611 ms`）**，单槽 median 最低达 **`9.0372 ms`**（见 [ViT Inter-Block Byte Stream 报告](results/vit-inter-byte-20261014/README.md)）；随后完成 **C512 16-Block 块间 1B E4M3 字节流直连 + ViT 进出边字节化 + Downsample C64/C128 字节边（`c512-byte-stream-20261014`，`HIP_VIT_INTER_BYTE=15` 默认开启）**，导出 `mh_pool_project_group_c{64,128}_hin_out8`、`mh_pool_project_group_c{256,512}_out8`、`vit_gather_b8`、`decoder_project2x_h16w[_byteout]_w_bin`、`split_ffn_one_w2f8_w16_bin`、`split_projection_frag_w16_bskip` 与 `mh_attention_project_frag_c512_w16_u4_bout`，**消除全网最后 1 次 `vit_pack_input` 发射（全网发射数 `154 → 153`，8 个 ViT block `vit_pack_input` 8/8 清零）**、消除每帧 **`632.17 MB`** 的 `float32 <-> uint8` 冗余往返与 `split_ffn_one_w2f8_w16_bin` 每 wave 64 条 `v_cvt_pk_fp8_f32` 重打包指令，并将运行时池显存由 **`277.1 MiB` 降至 `276.0 MiB`（净省 `1.1 MiB` VRAM）**，1920×1152 六模式 Gold 逐位一致（`0900E489...`），在 `e337af3d` 基线上完整 Frame 3 轮 4-slot ABBA（960f/arm）3/3 轮全胜（`-45.4 / -43.7 / -52.4 µs`），pooled mean **`9.1021 → 9.0549 ms`（`-0.0472 ms` / `-47.2 µs`，median `9.1010 → 9.0485 ms` / `-0.0525 ms`，p90 `-33.0 µs`，p99 `-39.0 µs`）**，且 **`r1/candidate-B2` 单槽 160 帧稳态达 `8.9601 ms` mean / `8.9445 ms` median，正式突破 `9.0 ms` 大关！** 单日七场战役累计净降 **`-0.5812 ms` mean / `-0.6004 ms` median**（见 [C512 Byte Stream 报告](results/c512-byte-stream-20261014/README.md)）；伴随排查的 C256 Attention W16（`+0.8 µs` 打平，8-wave WG 屏障已掩盖 8B fragment 加载）与 C256 `SpStage` 首尾层扩围（`W2_FAST_NUM` 合同差异及单层 LLVM23 `W2_QKV_FUSE=3` 更快）已证实为伪机会并记入负账。同日完成 **`NativeLowFrequencyTemporal`（MODE 2/3）64-Slot Ring 化**，对齐 MODE 1 `NativeAddonFastHistory` 消除每帧 `CreateDescriptorHeap` 与 `NativeGameFrame::ProcessSubmittedFrame` 中的 2 次额外 `r.submit.Flush()`，MODE 2/3 单元测试与 12 帧多帧时序 Gold 逐位一致（`0 bit-diff`），延迟提交 `DLSS5_TEST_ASYNC_SUBMIT=1` 下 3 轮 ABBA 3/3 全胜（`-0.070 ms / frame`，见 [low-temporal-ring 报告](results/low-temporal-ring-20261014/README.md)）。剑星最后确认仍为已安装64dc/MODE0/MP1/1x，本次发版与实验均未替换游戏安装。历史见 [DevHistory.md](DevHistory.md)，负账见 [failed-experiments.md](failed-experiments.md)。

## 两候选顺序试验：已结题，均未采纳

持久树 `/home/lmxxf/work/dlss5-two-kernel-trials`，research基线4a9d7eee(parent79599997)。V末rendezvous数值/ISA通过，但唯一662786孤立筛选控制漂移−79.005µs大于pooled改善−39.2475µs，收益未证，STOP、不Frame、不重跑。prefix主输出八store TH_STORE_NT的ISA/完整双输出18221/真实Auto Frame79532均通过；唯一89008整Frame320弃80×四槽：mean9.656520833→9.655660417ms（−0.8604µs），p99−20.480µs、max−21µs，控制漂移+26.408µs，后B比后A慢1.5µs，不能认定稳定收益，STOP、不换hint/刷轮。初次68401因私有style资格误拒未启用候选，保留原失败并仅修host，非算法失败。

两候选均只保实验源码/统计/审计，不进产品；原43模块/正式实现/installed64dc与游戏配置未改，未部署/push，GPU无live。详见 [two-kernel-trials](HIP/experiments/two-kernel-trials/README.md)。本轮授权实验已完成，未启动第三候选。

## 三项最终裁决

1. **无history会话：采纳。** 显式NeverHistory，公共unknown默认保旧，所有temporal入口拒违反，不热分配。43364完整Framegold0，fresh会话实际少一项35389440B=33.75MiB共享buffer/导入，candidate创建2/import2/poolhits0；driverfree另录+67.5MiB，不解释为物理双份或峰值。36250 Framewall微+3.596µs，小于26.392µs控制漂移，无稳定加速。DirectHistory/实验/未声明会话保旧。
2. **C512未用mixed/contract：停止、撤回。** 26032实际48calls/fallback0/gold0，但best-fit池290571128→292742008B反增2170880B，driverfree仅+64KiB，逻辑少New未带来净省。a5786fbb已恢复共享原两New；不perf、不调池，候选与原负证保留。
3. **ViT活scale尾紧凑：contract与projection均采纳资源收益。** 仅搬原packed字节与4096B F32尾、改变新export尾地址，精度/math/累加顺序不动。contract79561实省96MiB，projection11819在已启contract上实省24MiB；两轮ABBA均值变化−8.569/−1.756µs均低于控制漂移46.113/26.492µs，不宣提速，单max分别+0.258/+0.187ms保留。最终生产同宿主66725/两43模块旧新路径gold0：weights423438120→297609000B净省120MiB，history0，8+8新keys，无侧车/NR实验开关。

## 最终源码与边界

- 默认内部紧凑开关只在已审gfx1201/RX9070XT、1152固定profile及正确byte-edge消费者生效；未知selector、自定义模块、缺新export/已有legacy cache保持旧buffer+旧kernel成对，gfx1200保旧，不宣双架构实机验证。官方既有vit_stream recipe自然构建两newexport，不增加永久模块或用户配置。
- 最终正式Frame宿主O2 99541=0、addonO2 30670=0，jointCOMGR94285=0；旧86个及两accepted候选87个函数对joint均逐原始函数字节一致。实际emitted helper CPU default1/off/unknown/cache/layout兼容门通过；正式66725全帧firstlast0900/finite/Auto3/原模块身份与旧模块fallback通过。证据索引 [resource-followups](HIP/experiments/resource-followups/README.md)。
- **游戏里仍是已安装64dc/原MODE0/MP1/1x，正式0.41不变。本次33.75MiB共享资源与新增120MiB权重减少尚未部署到游戏，未push。两类分配宽度相加153.75MiB，不能称驻留峰值减少，也没有可靠加速结论。** 先前expand已省96MiB包含在本轮基线中，不能重复报作新收益；用户58.2fps是此前现场观察，不是这些新改动的性能证据。分配宽度、driverfree快照、驻留峰值严格分列，三轮性能不相加。

## 本轮真实Auto2测量：有限可用，只作host粗定位

- 只在私有宿主加11个host QPC点，预分配、末尾导出；原Network头逐字不变，无新增GPU事件/query/marker/等待、无绕过Auto guard。95980数值门、31627四角色A/A均真实exit0/released，当前joint43模块/0900输出/8+8权重/history0相同；每角色Auto实际record_ok/accepted320、reject0、PDL calls0。计数一致证明路径身份，不能证明GPU排程时刻完全不变。
- **A/A不能证明零扰动。** 320帧弃80、480/arm：off9.6242125→on9.647700ms（+23.4875µs），p99+4.750µs，控制漂移+28.725µs；两B槽都高于两A槽，保留正向串扰可能。不重刷、不据几µs差选新刀；gold的MemoryReport同步/冷帧不当时间账。
- on480只读CPU经过时间：input录/交约0.034ms、HIP发核API约0.354ms、output录/交约0.020ms、原emptySubmit+Flush完成动作约9.188ms。最后一项**不是9.188ms可删除CPU开销，不是GPU执行或空档**；可能包含等待实际GPU/队列完成，当前无法分开。没有GPU内部stage占比证据，不能把这些段相加/相减反推GPU分布。
- **唯一后续建议：先审实际GPU调度trace的可行性。** 当前未有已验证的低扰动、HIP队列可见且校时可靠的外部trace证据；现profile/dup/wall/timing/span改变Auto路径，旧家族表不当当前热点。没有这种证据就暂缓默认host优化假设，不继续微改或造完整profiler。本任务到文档交付止，未排下一实验。
- MODE2/3两外层Flush已完成64-slot ring改造并移除（`results/low-temporal-ring-20261014/`，不计作MODE0收益）。

### 鸠建议：只列待查边界，不排GPU

- **Non-temporal存储：** 只审低复用末端输出；马上被消费的中间量不盲目旁路缓存。TH不是保证绕过L2；旧decoder“NT”指tile数，不是non-temporal，不能误写成这条路线已失败。
- **Split signal/wait：** 先找得到可插入的具体独立计算；leave不是arrive，且不能替代LDS数据完成所需的wait。没有独立工作与同步证明就不改。
- **原生FP8：** 当前已大量使用；只做反汇编漏网审计，不从此直接跳到手写汇编重写或虚构收益。
- **Lower occupancy：** C512_MIX与VIT_CONTRACT_OCC_LDS4096已有采纳，不能换名重复；wave宽度不等于驻留数量，需实际资源/关键路径新证据。
- **多stream：** stream不保证独立ACE。未找到具体无依赖且处于关键路径的工作前，不排多流实现。

## 固定工作规矩

- 所有GPU/RTC操作先game-check、RTC/进程检查、至少100GB实验盘余量、原子 `gpu.lock`；每15秒检查游戏。游戏运行不抢GPU、不启动/结束游戏、不换DLL、不升降驱动，只继续CPU。
- watchdog仅终止本次owned PID并等待真实退出、释放自己锁；保存actual handle/PID/exit和timeout，禁止对timeout未知job重开。同handle收终态，不以SSH断开代进程完成。
- 保K累加顺序、舍入、FP8/Half编解码、NaN/±0合同。先证scope再跑；负均值/退尾不刷轮，坏event负值/近零批不计性能。
- 生产/玩家配置/安装资产保持；后续若用户另授权安装，必须具体包身份→备份→读回校验→回滚路径。只本仓工作，不改外层仓。

## 已完成且不重开的基线

- 正式0.41、tag `523723fd`、三个已上传ZIP及镜像不变；载荷源码标记 `ab8e3e82`。发布默认单遍，预测仅3x选项执行两遍+预测第三，肤色保护默认off。正式包38模块/架构、76总计，与后续本机开发载荷分开。
- 0.41后三项（final RGB免copy、block4 pool字节边、真实1440 FAST3 SP）已按各自scope完成，不跨批相加FPS；H900原布局normhoist只限已验900范围，1152尾负不启；单timed Auto提交marker已接受，不能拿pulseoff当当前APP基线。
- 当前剑星保持 **MODE0/MP1/PRED0/SKIN0/1x**，已核安装addon `64dc04286c22d5d3…`，79模块/Runtime与配置未改，见 `results/stellar-compact-trial-20261012/`。`9413682f`只是10-11恢复时的历史载荷，见 `results/stellar-mode0-restore-20261011/`。用户最新观察静态58.2fps，旧MODE3约54fps与MODE0约58上下均非同场景ABBA，不归出精确算法收益。鬼武者此前MODE1/MP1及独立配置本次不改，实际运行状态仍须操作前重查。
- MODE3同NN/samecodec旧HDR菜单说明修正幅度+45.2%、局部反差/颜色可辨，未证新细节/画质改善；用户未保留。skin启发式保护亦用户关闭，YuNet只单菜单demo；人物保护模型调研未选型/未游戏集成，不能列已验证小脸方案。
- ViT tile-ready `0431ba0e`已STOP：真实矩阵overlap且pair byte0，但公平GPU70.043→95.770µs、wall106.475→141.603µs，不整帧/不续变体。QKV宽尾、graph替换真实Auto产品（含 `ReplayOff` 161节点及 2026-10-14 结题的 `ReplayAuto` 162节点强DAG `results/graph0-replay-auto-20261014/`）等负账直接检索总账，不换名重复。
- current71 nativeD3D12独立分支 `b834a93f`受控185端点+final+poison全0，但GPU301–304ms对HIP约9.2ms，约33倍慢；不重启全移植，不把globalUAV桥成本归API固有差。未部署游戏。
- 完整负账 `967df5a3`，369候选分组，覆盖早HLSL/DirectML/多轮HIP/compiler/graph/interop与近期结果；以后提优化先核旧候选真实条件，修复后采纳者不能当永久失败。

## 仍未完成的其他主线（本轮不扩大）

1. **真实房顶闪烁/时序质量**：拍屏111.mp4不能替代原始连续color/MV/depth/jitter/exposure/reset。原history HALF4合同、RTZ/内部blend与受控工具链已取证，真实反光/遮挡/拖影是否改善仍未验证；不继续synthetic代真实场景，不把跳ViT删反光当无损修复。0.41-a临时历史试验默认off，正式0.41不动；资产/试包状态以各receipt为准，不沿旧“正在构建”文案。
2. **mochi差距**：旧锁定同1088/full71对照曾有约1ms量级差，但各自noise/数学/plan/输入输出边界必须分列；a9b13dd ACO同时改Linux shader、TCHAIN/weight plan，其5.7ms不是HIP换compiler可得。未有值得立即编码的泛“融合/地址外提”新刀，本轮资源三项已结题；未追加新的实现任务。
3. **人物保护**：正常游玩小脸/脸颈一致需求保留。整人mask模型离线真游戏集、多人/遮挡/边界/时域稳定与AMD互操作成本均未验证；face parser只是第二阶段，RVM/SAM仅参考，不本轮装模型/改游戏。
4. 真实新硬件/gfx1200/game/MP3/history组合及未验导出不借其它shape门；接口源码审、单图demo或部署成功均不当性能/观感完成。需要这些现实输入时再按用户范围安排，本轮没有为此追加实验。

## 2026-10-12 本机试用更新

剑星已按授权安装紧凑权重正式O2 addon `64dc04286c22d5d3…`（源码 `1b4c898f`，部署57883 exit0）；MODE0/MP1/PRED0/SKIN0及其他配置字节不变，模块/Runtime不变。用户已实玩并反馈静态58.2fps；无旧版同场景严格对照，不当ABBA或新发版。回执与回滚：`results/stellar-compact-trial-20261012/`。

- 2026-10-12 12:54 用户反馈“有提升”，通过Splashtop玩剑星，用户原称“2k AA(1080P dlss5) exact”，静态画面稳定58.2帧；对应addon `64dc04286c22d5d3…`，MODE0/1x设置未改。属实玩观察，旧版无同场景精确对照，不报精确增幅。

## 2026-10-14 《剑星》与《鬼武者》本机安装更新

已按用户指令将今日全部验收合入的 `be506729` 基线（含 C512/C32/ViT W16、全网 Epilogue 无分支与 `v_movrel` 清理、ViT/C512/Down 1B E4M3 字节流直连 `HIP_VIT_INTER_BYTE=15` 及 `MODE 2/3` 64-slot ring）部署至《剑星》与《鬼武者》：
- **《剑星》**：更新 `dlss5-amd.addon64`（`64dc0428… → 91d8147188b950367d40ed041588a0591ccbc0d4627ff70702b9a4e68eb0cd26`）及双架构 80 个 `.hsaco` 模块；个人配置 `custom-config.txt`（`MODE0/MP1/PRED0/SKIN0/1x`）字节未改。
- **《鬼武者》**：更新 `LmxxfNrRuntime.dll` 与 `_storage_\LmxxfNrRuntime.dll`（`3eaed204… → 50c3b80b730fce925c65c83a803c42406e6644f03e0fb0ae71535bbd88567844`）及双架构 80 个 `.hsaco` 模块，并通过 `runtime-smoke.exe` 冒烟校验（`PrepareFrame rc=0, HIP rc=0, lmxxf_nr_gpu: ok`）；个人配置 `custom-config.txt`（`MODE1/MP1/PRED0/SKIN0`）字节未改。
- 备份目录：`D:\DLSSNR-Lab\game-install-20261014\backup-20261014-233615`，回执与一键回滚见 [game-install-20261014](results/game-install-20261014/README.md)。
- 2026-10-15 00:14 用户实玩反馈：“试了一下， 剑星 稳定在60帧了。”（对应已装 `91d81471…` + 80 模块，`MODE0/MP1/PRED0/SKIN0/1x` 设置未改；此前 10-12 紧凑权重版 `64dc0428…` 实玩观察为 58.2 帧）。


