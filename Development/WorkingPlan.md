# 当前工作计划（WorkingPlan）

更新：2026-10-18（开发载荷源码 `10982cf4`；五项优化已结题，完整回执见 `results/five-final-20261017/`；本机双游戏已装 `10982cf4`；正式0.43本地三包已完成）。历史流水见 [DevHistory.md](DevHistory.md)，负账台账见 [failed-experiments.md](failed-experiments.md)。

---

## 1. 当前基线与本机状态

### 1.1 发行包基线（0.43，2026-10-17，公开三包已交付）
- 载荷源码 `10982cf4`；复用已验宿主/双架构80模块，不重跑模块编译或ABBA。
- `D:\給網友打包`：Magpie `345,297,302 B`（SHA `b3450315…`），通用OptiScaler `375,495,322 B`（SHA `e507a6b4…`），OptiScaler-REFramework `430,517,634 B`（SHA `0ac552c4…`），每个ZIP附 `.zip.sha256`。
- 每包44项shader、RE9包内smoke、ZIP逐文件回读及独立默认/80模块/宿主检查通过；回执见 [releases/0.43](releases/0.43/README.md)。
- **0.43 公开镜像**：[夸克](https://pan.quark.cn/s/3b19c0403e3f) · [Gofile](https://gofile.io/d/hz5cDOPF)（0.42 旧镜像 [夸克](https://pan.quark.cn/s/316704620069) / [Gofile](https://gofile.io/d/HNE20Ocp) 及旧ZIP保留）。
- **版本单帧耗时（`frame.exe` 稳态均值，RX 9070 XT）**：**1080 档（1920×1152）`9.121 ms`**（最佳单槽 `8.960 ms` mean / `8.945 ms` median；0.42 为 `~9.65 ms`），**900 档（1600×960）`6.535 ms`**。**Zero 2026-10-18 定规**：因游戏内 1x 帧率已顶满 60 FPS 上限看不出差距，以后直接记录每个版本的单帧耗时（`ms/frame`）。
- 继承0.42资源优化：已验范围内216MiB持有权重容量与显式无history会话33.75MiB共享buffer容量节省，非驻留峰值。

### 1.2 开发主线（10-14 七场战役 + 10-17 收下候选1/3）
在 0.42 之上完成 2026-10-14 全网 W16 权重分块、ISA 去分支与跨核 1B E4M3 字节流直连（1920×1152 Gold 首尾帧 SHA256 全程逐位锁定 `0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A`，`0 bit-diff`，`extra_vram_bytes=0`）：
1. **ReplayAuto 162 节点强 DAG 结题（STOP）**：修妥 ROCm 7.0.2 CLR `hipEventRecord` 流捕获缺陷并过 12 帧 Gold，但 3 轮 ABBA pooled `Δmean = -17.25 µs`、`Δp99 = +4.00 µs`（R3 双退步），hipGraph 全家桶在 RX 9070 XT 上彻底封板，生产保持 `EagerAuto`（`DLSS5_SUBMIT_PULSE=2, opt.graph=0`）。
2. **C512 三核 W16（`HIP_C512_W16=2`）**：`split_projection_frag_w16`、`c512_qkv_attention_compact_w16`、`mh_attention_project_frag_c512_w16_u4` 改 16B `global_load_b128`，3 轮 ABBA `-16.7 µs` mean。
3. **C512 Split-FFN W16（`HIP_C512_FFN_W16=1`）**：`split_ffn_one_w2f8_w16` 消除 256 条跨步 `global_load_b64` 为 128 条 100% 合并 `global_load_b128`，3 轮 ABBA **`-131.2 µs` mean / `-134.5 µs` median**。
4. **C32 Wave1 W16（`HIP_C32_W16=1`）**：`c32_wave1_*_w16` 将 88 条 `global_load_b64` 合为 30 条合并 `global_load_b128`，3 轮 ABBA **`-24.0 µs` mean / `-32.8 µs` median**。
5. **ViT 核心三算子 W16 + 外层分片禁展开（`HIP_VIT_W16=7`）**：Contract VGPR `211 → 115`（Occupancy `6 → 8`）、Projection VGPR `190 → 114`（Occupancy `6 → 10`），3 轮 ABBA **`-56.6 µs` mean / `-66.5 µs` median**。
6. **全网 ISA Epilogue 清理 + 二轮病灶审计**：消除 `mh_pool_project_group` 与 `mh_attention_project_frag_c512` 的 `v_movrels_b32` 及百余条 `s_cbranch`，统一无分支 `fmed3f(x+0.f, -448.f, 448.f)`，向量化 `c32_wave1_finish/post` LDS/全局写，两轮合计 **`-151.8 µs` mean / `-153.0 µs` median**。
7. **ViT + C512 + Downsample 1B E4M3 字节流直连（`HIP_VIT_INTER_BYTE=15`）**：消除全网全部 8 次 `vit_pack_input` 发射（每帧总发射数 **`161 → 153`**），每帧砍掉 **`681.45 MB`** 冗余 `float32 <-> uint8` 流量，池显存 `277.1 → 276.0 MiB`（`-1.1 MiB`），两轮合计 **`-217.6 µs` mean / `-213.6 µs` median**。
   - **1080p（`1920×1152`）整网 `frame.exe` 稳态耗时**：由 `9.6070 ms` 降至 **`9.0549 ms` pooled mean / `9.0485 ms` pooled median**（最佳单槽 **`8.9601 ms` mean / `8.9445 ms` median**，累计净降 **`-0.5812 ms` mean / `-0.6004 ms` median**）。
8. **`NativeLowFrequencyTemporal`（MODE 2/3）64-Slot Ring 化**：消除 MODE 2/3 每帧 `CreateDescriptorHeap` 与 2 次 `r.submit.Flush()`，异步提交下 `-0.070 ms/frame`。

**2026-10-17 本轮结题**：五项按序完成，收1/3，停2/4/5。干净默认构建的1080/900 Gold逐帧一致；每档3轮ABBA的均值全部改善，pooled mean分别−20.846/−34.487µs（**1080 档 `9.1422 → 9.1213 ms`，900 档 `6.5699 → 6.5354 ms`**），pooled p99−25.690/−32.351µs。1080 R2 p99+10.599µs原样留档，不称每轮尾都好。最终80模块逐SHA/实际ELF目标核验通过（旧RTC错误gfx1200标签已用当前源码工具修正，实测gfx1201字节未变）；gfx1200仅编译核验。addon/runtime构建与runtime API smoke通过，产物在 `D:\DLSSNR-Lab\five-final-20261017` 和本地 `/home/lmxxf/work/dlss5-five-build/final-payload/`。

**当前状态**：0.43 正式三包与网盘镜像已全部交付完毕。详 `releases/0.43/README.md`。

### 1.3 本机游戏现装（2026-10-17，鳩部署10982cf4）
- **《剑星》**：addon SHA `2cefc60d50906d9a5dcf542f1c890819fcaa01b2d712047423d303b8f0475e5b`，80模块；配置MODE0/MP1/PRED1/SKIN0，个人配置文件字节未改。用户实玩确认帧率已贴满上限看不出差异，以后直接记录各版本单帧耗时（`0.43`：1080 档 `9.121 ms` / 900 档 `6.535 ms`）。
- **《鬼武者》**：runtime根目录与_storage_均为 SHA `bc7b77049f828e1500bfe447d9f09c963b38b2c5584c104f65650e5127f8decd`，80模块；MODE1/MP1/PRED0/SKIN0，个人配置字节未改，API smoke exit0。
- **备份/回滚**：`D:\DLSSNR-Lab\game-install-20261017\backup-20261017-233600`；详 [安装回执](results/game-install-20261017/README.md)。

---

## 2. 新主线：310.9.16 CC_SMALL_FP8 接入（静态分析完成，HIP待实施）

**2026-10-18 已交付逆向报告**：[dlssnr-310-9-16-analysis-20261018](results/dlssnr-310-9-16-analysis-20261018/README.md)，含77/153记录、76层、291子区段、255导出项、31块与旧HIP逐块映射及实施阶段。只做CPU解析/提取与planner验证，未执行新DLL/NGX/GPU；未改生产代码、已装双游戏或正式0.43 ZIP。

### 已确定，不重复调查

- DLL310.9.16.0，266424944B，SHA `2bc19bc09a7b89dd44f73e2ac0108fcc586e2154bdd0830f242f4f040e28789f`；Preset1旧HT资源与310.8整段SHA完全相同，Preset2/default新增`WEIGHTS_CC_SMALL_FP8`。
- Small31块/76层/77资源记录，正式255项pack113917248B，SHA `7e966e2639dbec6596aa0bac3b8761137d2c40ca8cb4aca30df7ca10043c6e33`；Python和指定C++源码的本机CPU构建提取逐字节一致。PR13是256项/另带blend条目，不能混用指纹。
- ViT仍8块，边界11..18；Post30，blend half `0x3A23`=0.76708984375；按本仓布局的新history行6 SHA `c4c5f5189360756001e96abb43a482396ac8bde56f6ac4c7c19ae63db01d0980`。Model Preset与Style分开。
- 六skip：19←10、22←8、24←6、26←4、28←2、30←0（前三位之外还要保正确pre-down/pre-pool输出）；真实层表skip ordinal见报告。
- Small native工作域：1080→1920×1152/ViT640；900→1600×1024/448；720→1344×768/288。900的深层宽100→52→28，720有防整除宽轴补64；不是当前固定900/720几何，也不能只改H或ViT token常量。

### 顺序实施

1. **P1模型/资产身份**：保Original默认与0.43行为；引入不可变ModelSpec（图、类型/shift/terminal、skip、ViT/Post边界、blend、几何/指纹）。逻辑31 ID与legacy kernel role、资产名分离；独立Small目录/缓存身份；模型切换drain/reset并重建，日志必须有requested/effective model，显式Small缺资产不能默默测旧网。
2. **P2先固定1080正确性**：新权重用现有exact解码器生成本仓布局；可先RunSmall复用kernel roles。MP1/Style/seed明确，history/AE/skin/Sp/PDL/Pulse/graph先关；逐节点保存并对310.9.16 Preset2 oracle。先用已验F16 Up和明确中间张量，尤其不纳入已Gold失败的C32 FP8 Up候选。新Small另立gold；旧0900只保护Original。
3. **P3几何与时序**：逐节点ceil-half/round4、skip恢复、有效尾/零填充/stride后再开900/720/free。新head/gate与blend独立参数化，不提前缩放historyStrength改变saturate语义；随后验证reset/MV/exposure/resize/模型切换、AE新gain、多遍与可选时域。
4. **P4性能与产品**：Small同模型数值门后3轮ABBA及Zero游戏观感，再考虑单plain+DS/UPS的Sp策略及提交功能。旧full71性能资格不自动适用Small，不重开hipGraph/INT4。双架构编译/实际ELF目标核验与Original回归独立完成；现有GPU锁/看门狗规矩照旧。

当前不存在可用Small HIP开关或Small发行包；报告中的新配置/ModelSpec是实施建议，不代表0.43已支持。0.43本地三包与已装10982cf4保持；公开上传仍等用户指令。

---

## 3. 2026-10-17 候选与实测结论（已全部结题：收1/3，停2/4/5）

以下保留基于 `be506729` 的原始五项审计提案；是否成立以各节实测状态为准，不能把提案中的逐位/收益假设当成验收结果。汇总见 `results/five-final-20261017/`。

### 候选 1：Block 47 → `Up(48)`（`512 → 256`）1B E4M3 字节边接通 + `Up(39)`/`Up(48)` W16 FP8 WMMA（`HIP_DEC_F8_W16`）

**2026-10-17 已验收合入**：Gold 0 bit-diff；3轮ABBA均值全改善、p99全改善，pooled mean −17.398µs / p99 −23.962µs。默认 `DecoderF8W16Mode=3`；详 `results/decoder-f8-w16-20261017/`。下方原审计说明保留，下一项候选2。

1. **Block 47 → `Up(48)` 1B E4M3 字节边（零核改动或仅宿主接通）**：
   - **现状病灶**：`hip_reference_network.h:1025` 在 C512 解码段 `for (U b=40; b<=47; b++)` 仅对 `b < 47` 开启 `byte_out`，导致 Block 47（`post=0`，输出原本就是精确 E4M3 格点值 `F(Hrtz(acc))`）仍写出 `4.42 MB` 的 4B FP32；紧接着 `Up(48)`（`512 → 256`，`60×36 → 120×72`）在 16 个输出列分片上把这 `4.42 MB` FP32 重复读取 16 遍（**`70.78 MB/帧`**，每 wave 发出 `256` 条标量 `global_load_b32` 并转 `_Float16`）。
   - **现成基础**：`hip/deep_fast.hip:541` 的 `decoder_project2x_h16w_byteout_w_bin` **已经编译进了 `if (inputs==512 && outputs==256)` 分支**，仅因 `hip_reference_network.h:903` 的 `byte_in` 检查写死 `ic==1024&&oc==512` 且 `line 1025/1035` 未传 `byte_out/byte_in` 而未生效。
   - **物理收益**：接通后每帧直接消除 **`56.40 MB`** 全局显存流量（Block 47 少写 `3.32 MB` + `Up(48)` 少读 `53.08 MB`），`Up(48)` 输入加载由 `256` 条 `global_load_b32` 缩减为 `32` 条合并 `global_load_b64`，**0 字节额外显存、100% 逐位一致**。
2. **`Up(39)`（`1024 → 512`）与 `Up(48)`（`512 → 256`）W16 FP8 WMMA + 字节输入直喂**：
   - **现状病灶**：`decoder_project2x_h16w_wide_body`（`hip/deep_fast.hip:518`）即使在 `ByteInput=true` 时，仍先把 1B E4M3 输入逐字节解包（`v_bfe_u32` + `v_cvt_f32_fp8` + `v_cvt_f16_f32`，`Up(39)` 每 wave 白跑 **1,536 条 VALU 转换**，`Up(48)` **768 条**），再去读**未分块 row-major `_Float16` 权重 `w16+(row+rc())*inputs+k+gr()*8`**——相邻 lane `rc=0..15` 跨步达 **`2,048 B`（`Up(39)`）/ `1,024 B`（`Up(48)`）**，每条 `global_load_b128` 打散到 **16 条不同 cache line**！此前 `2026-10-01 §11` 测试 `HIP_DEC_F8W` 时既无 `ByteInput`（还在用 `dec_pack8` 现场把 FP16 转回 FP8），权重也是未分块 row-major。
   - **改造方案**：`decoder39-weights.f32` 与 `block48-weights.f32` 矩阵区已于 `2026-10-01 §9` 实测 100% 落在 E4M3 格点且 `wmma_fp8_fp8` 与 `wmma_f16` 19 组逐位一致。原地复用 `@decoder-f16r` 键将矩阵区打包为 `FragmentPackedMatrixW16` E4M3，核内直接用 1B E4M3 `ByteInput`（`i2 a0, a1`）与 16B 合并权重（`w16_i4 bw`）执行 `wmma_f32_16x16x16_fp8_fp8_w32_gfx12`：
     - 消除 `Up(39)`/`Up(48)` 全部 **1,536 / 768 条输入转换指令**；
     - 权重加载指令数减半（`128 → 64` / `64 → 32`）且从 16 路跨行散读变为 **100% 合并的 512B 全 wave 连续加载**。

### 候选 2：在写入端消除全网最后 2 次 `vit_gather_b8` 发射（发射数 `153 → 151`，释放 `5.0 MiB` `gather_maps` 显存）

**2026-10-17 已结题 STOP**：Gold 0 bit-diff；三轮ABBA均值全非改善，pooled +5.691µs，保留生产两次gather。详 `results/vit-write-gather-20261017/`。
- **现状病灶**：全网在 `Down(30)` 后与 `Block 38` 后各调 1 次 `vit_gather_b8`（共 2 次 launch），每次每个线程还要从显存读取 16B 的 `uint32_t indices[655,360]` 查找表（常驻占 **`5.0 MiB` VRAM**，每帧额外读 **`5.0 MiB`** 索引表 + **`1.31 MB`** 字节搬运）。
- **为什么 2026-09-30 的 `HIP_VIT_GATHER_FOLD_HOST` 在 900p 变慢**：当时把逆重排塞进了**读取端 `Up(39)`（`decoder_project2x_h16w_gin`）**——不仅丢掉了 `_w` 宽尾优化，而且 `Up(39)` 对每个输入 token 要跨 32 个输出列分片**重复读取 32 遍**，在读取端做 `vg_cinv` 通道重排把 32 遍连续向量读全打碎成了标量散读。
- **正确姿势（双写入端重排）**：
  1. **入口写入端 `Down(30)`**：`mh_pool_project_group_body`（`hip/multihead_fast_padded.hip:424`）**本来就有 `Gout=true` 分支**（`pg_tinv(q)*N + pg_cinv(c)`，仅 6 条位运算指令）！只需在 `c512_head_group.inc` 导出 `mh_pool_project_group_c512_gout_out8`（`Gout=true, ByteOut=true`），即可在 `Down(30)` 写出 `640 KB` 1B E4M3 时直接按 ViT 顺序落盘，省掉入口 `vit_gather_b8`。
  2. **出口写入端 `Block 38`**：在 `vit_stream_project_tiles`（`hip/vit_stream.inc:66`）新增 `Gout=true` 导出 `vit_stream_project_n64_bb_bout_gout_compactw_w16`，仅在 `block == 38` 写出 `640 KB` 1B E4M3 时按 `raster(t)*1024 + ch(c)` 落盘（每个字节只写 **1 次**，L2 内完成）。下游 `Up(39)` 原封不动继续走 `decoder_project2x_h16w_byteout_w_bin` 的连续 8B/16B 合并读取！
- **物理收益**：全网每帧 kernel 发射数 **`153 → 151`**，释放 **`5.0 MiB`** `gather_maps` 显存（`gather_maps_MiB: 5.0 → 0.0`），每帧再省 **`6.4 MiB`** 显存流量，100% 逐位无损。

### 候选 3：`Down(8)`、`Down(14)`、`Down(22)`、`Down(30)`（`mh_pool_project_group_c{64,128,256,512}`）W16 FP8 WMMA + 池化去分支

**2026-10-17 已验收合入**：Gold 0 bit-diff；三轮均值/p99全改善，pooled mean −20.704µs / p99 −27.539µs。池化有效性/顺序保留，采纳FP8字节LDS与W16矩阵路径。详 `results/down-f8-w16-20261017/`。
- **历史误判纠正**：`2026-10-01 §9` 普查曾验证 `block{8,14,22}-ds.f32` 与 `head-matrix.f32` 权重 **100% 在 E4M3 格点上**，但误以为激活输入是 `raw`（`Hrtz`）而标为“不在格点”。实查 `mh_pool_project_group_body`（`hip/multihead_fast_padded.hip:415`）：
  `v = F(H(H(top + bottom) * .25f)); pooled[k*S + c] = (_Float16)v;`
  2×2 池化均值在写入 LDS `pooled` 之前 **已经过 `F()` 量化到了精确 E4M3 格点（且 `-0.0f` 已转 `+0.0f`）**！
- **改造方案**：
  1. `pooled` 直接存 1B E4M3（LDS 占用减半：`c512` `16.6 KB → 8.4 KB`，`c256` `8.4 KB → 4.3 KB`），`@ds-frag` 原地改为 `FragmentPackedMatrixW16` E4M3 权重；
  2. 每个 K32 `chunk` 内用 1 条 `ds_load_b128` + 4 条合并 `global_load_b128` 喂入 `wmma_f32_16x16x16_fp8_fp8_w32_gfx12`，保留每 K32 步末尾的 `acc[j][e] = H(acc[j][e] + sum[j][e])` 舍入边界，**100% 逐位等价**；
  3. 顶部 `for (uint k=0; k<16; k++)` 池化循环对内部完整 tile（`first + 15 < M && !valid_width`）走无分支快路，消除现存的 16 个循环分支。

### 候选 4：`Down(4)`（`mh_pool_project_c32_b8_out8`，`480×288`）4 列分片合波（`34,560 → 8,640` waves）+ W16 权重

**2026-10-17 已结题 STOP**：Gold 0 bit-diff；三轮均值全部退步，pooled +5.546µs，保留生产旧四wave。详 `results/pool32-wave-w16-20261017/`。
- **现状病灶**：`mh_pool_project_c32_b8_out8`（`hip/multihead_fast_padded.hip:374`）每 wave 只算 16 列（`nt=4`），导致 `138,240` 个 token 发射多达 **`34,560` 个 wave**，每个 16-token 输入块被 4 个独立 wave 重复读取 4 遍，且权重 `(col+rc)*32 + half*16 + g*8` 是未分块 row-major（相邻 lane 跨 32B）；尾段还多做了一次无意义的 `acc[e] = Hrtz(0.f + sum[e])` 和双重 `q8(F(acc[e]))`（两次 `cvt_pk_fp8_f32`）。
- **改造方案**：对齐 `mh_pool_project_group`，改为每 wave 负责 16 tokens × 64 全列（`nt=1`，总 wave 数砍至 **`8,640`**），输入 `pooled` 每 wave 只读 1 次，`@ds-cast` 原地用 `FragmentPackedMatrixW16` 打包为 100% 合并 `global_load_b128`，尾段直接 `fmed3f(Hrtz(sum[e]) + 0.f, -448.f, 448.f)` + 单次 `cvt_pk_fp8_f32` 写出。

### 候选 5：融合上采样块 `UpBody`（Block 56 `C128`、Block 62 `C64`、Block 66 `C32`）上采样投影段 W16 FP8 化

**2026-10-17 已结题 STOP**：56/62 Gold同但pooled mean +3.555µs/p99 +20.987µs；独立派发发现66原路径缺字节low导出，补通65→66后完整Gold失败（2,768,436 half值差），未进入完整组合ABBA。生产保原路径，详 `results/upbody-f8-w16-20261017/`。
- **现状病灶**：`swin_wave2_body<Up=true>`（`hip/wave_owned_mh.inc:328`）与 `cw_body<Up=true>`（`hip/wave_owned_c32.inc:223`）在 `LowByte=true` 时，仍用 8 条标量字节加载 + `cvt_f32_fp8` + `cvt_f16_f32` 构造 `h8 a`，并从**未分块 row-major `_Float16` `upw`**（跨 16 条 cache line）加载 `b` 跑 `wmma_f16`。
- **改造方案**：`block{56,62,66}-weights.f32` 矩阵区同样 100% 在 E4M3 格点上。将 `in` 改为单条 8B `i2` 加载（零转换指令），`upw` 矩阵区原地按 `FragmentPackedMatrixW16` E4M3 排列并改用 `wmma_fp8_fp8`（尾部 `upw[IC*C + ...]` skip 缩放保持 f32 不变），消除标量拆字节与跨行散读。

---

## 4. 已封板边界（禁止换名重开）

- **hipGraph 全线封板**：旧 `opt.graph=1`、外层同工 `graph0`（`ReplayOff` 161 节点）与 2026-10-14 结题的 `ReplayAuto`（162 节点强 DAG，含 `EventRecord`）在 RX 9070 XT 上均无净收益或尾延迟退步，生产维持 `EagerAuto`（`DLSS5_SUBMIT_PULSE=2, opt.graph=0`）。
- **C256 `SpStage(16,6)` / `SpStage(49,6)` 边界不动**：首尾层（`15, 22, 48, 55`）因 `Block 22` `post=3` FP32 合同、1080p `W2_FAST_NUM=3 vs 0` 数值合同差异及 `c64-wave2-fast`（LLVM23 + `W2_QKV_FUSE=3` + `W2_FFN_QT_BATCH=4`）单层核快于 COMGR 持久核，不并入 `SpStage`；`sp_init_pair` 会禁用 `submit_pulse=auto`，不启用。
- **C256 Attention W16 / C64 & C128 FFN W16**：已实测在 4/8-wave WG 屏障下打平（`+0.8 µs` / `-1~-7 µs` 噪声），不合入。
- **Uniform-SGPR `m0` `v_movrel` 转三元选择树**：已于 `isa-audit2-20261014` 实测证伪（打断 VOPD 并生成 56 条 `v_cndmask_b32_e64`，退步 `+0.14 ms`），严禁替换 uniform SGPR 相对寻址。
- **C512 块内转置 WMMA FB8（`HIP_VIT_INTER_BYTE` bit 4 = `16`）**：已实现验证逐位一致且 3/3 全胜（`-37.6 µs`），但因转置 WMMA 下 `av8` 跨 512B 访问略弱于非转置 `mode=15`（`-47.2 µs`），保留为可选诊断位，默认维持 `HIP_VIT_INTER_BYTE=15`。
- **其余 370+ 历史负账**：动手前先检索 [failed-experiments.md](failed-experiments.md)。

---

## 5. 固定工程纪律

- **GPU 锁与护栏**：所有 GPU/远程 RTC 操作必须先做 `game-check`、进程检查、确认实验盘余量 `≥100 GB`、获取原子锁 `D:\DLSSNR-Lab\gpu.lock`，并挂 15 秒游戏看门狗；游戏运行期间严禁抢占 GPU、严禁替换 DLL/HSACO。
- **数值与验收门**：Original结构/布局/ISA优化必须对 `0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A` 逐位一致（`0 bit-diff`）；Small必须与310.9.16 Preset2另立gold，不拿训练差异强求旧0900，性能只认单进程同批交错 3 轮 4-slot ABBA（`edges_only=1, NET0`）。
- **版本与仓库卫生**：commit 不加 `Co-Authored-By`；共享分支禁止 `amend`；未经用户显式指令不改动已安装游戏文件或已发布 ZIP。
