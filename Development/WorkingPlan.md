# 当前工作计划（WorkingPlan）

更新：2026-10-17（基线提交 `3a1be68c` / 载荷源码 `be506729`）。历史流水见 [DevHistory.md](DevHistory.md)，负账台账见 [failed-experiments.md](failed-experiments.md)。

---

## 1. 当前基线与本机状态

### 1.1 发行包基线（0.42，2026-10-13）
- **正式三包**（位于 `D:\給網友打包`，载荷源码 `456b7e16`，构建归档 `88472e96`）：
  - `Magpie-DLSS5-AMD-0.42.zip`（344,087,793 B）
  - `OptiScaler-DLSS5-AMD-0.42.zip`（374,285,768 B）
  - `OptiScaler-REFramework-DLSS5-AMD-0.42.zip`（429,238,298 B）
- **公开镜像**：[夸克](https://pan.quark.cn/s/316704620069) · [Gofile](https://gofile.io/d/HNE20Ocp)，详见 [0.42 发布记录](releases/0.42/README.md) 与 [0.42 更新与使用说明](../0.42-更新与使用说明.md)。
- **资源基线**：紧凑权重合计省 `216 MiB` 分配容量（ViT expand `96 MiB` + contract `96 MiB` + projection `24 MiB`，`weights_count=184, weights_bytes=297,609,000 B`），显式无 history 会话另省 `33.75 MiB` 共享缓冲。

### 1.2 开发主线最新基线（`be506729`，2026-10-14 七场战役合入）
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

### 1.3 本机游戏现装（2026-10-14 部署，2026-10-15 实玩确认）
- **《剑星》**：已装 `dlss5-amd.addon64`（SHA256 `91d8147188b950367d40ed041588a0591ccbc0d4627ff70702b9a4e68eb0cd26`）+ 双架构 80 个 `.hsaco` 模块；配置保持 `MODE0/MP1/PRED0/SKIN0/1x`。**用户 2K AA（1080P DLSS5）Exact 实玩反馈：稳定 60 FPS**（此前 10-12 紧凑权重版为 58.2 FPS）。
- **《鬼武者》**：已装 `LmxxfNrRuntime.dll`（SHA256 `50c3b80b730fce925c65c83a803c42406e6644f03e0fb0ae71535bbd88567844`）+ 双架构 80 个 `.hsaco` 模块；配置保持 `MODE1/MP1/PRED0/SKIN0`。
- **回滚与回执**：`D:\DLSSNR-Lab\game-install-20261014\backup-20261014-233615`，详见 [game-install-20261014](results/game-install-20261014/README.md)。

---

## 2. 源码审计新发现的可优化候选（2026-10-17 梳理，全部属逐位无损 `0 bit-diff` 范畴）

对当前 `be506729` 的 153-dispatch 执行图与 18 个活跃内核源码进行逐边审计后，定位出以下 **5 项尚未采纳、物理机制明确且逐位等价（`0 bit-diff`）的优化点**，按收益把握从高到低排列：

### 候选 1：Block 47 → `Up(48)`（`512 → 256`）1B E4M3 字节边接通 + `Up(39)`/`Up(48)` W16 FP8 WMMA（`HIP_DEC_F8_W16`）
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
- **现状病灶**：全网在 `Down(30)` 后与 `Block 38` 后各调 1 次 `vit_gather_b8`（共 2 次 launch），每次每个线程还要从显存读取 16B 的 `uint32_t indices[655,360]` 查找表（常驻占 **`5.0 MiB` VRAM**，每帧额外读 **`5.0 MiB`** 索引表 + **`1.31 MB`** 字节搬运）。
- **为什么 2026-09-30 的 `HIP_VIT_GATHER_FOLD_HOST` 在 900p 变慢**：当时把逆重排塞进了**读取端 `Up(39)`（`decoder_project2x_h16w_gin`）**——不仅丢掉了 `_w` 宽尾优化，而且 `Up(39)` 对每个输入 token 要跨 32 个输出列分片**重复读取 32 遍**，在读取端做 `vg_cinv` 通道重排把 32 遍连续向量读全打碎成了标量散读。
- **正确姿势（双写入端重排）**：
  1. **入口写入端 `Down(30)`**：`mh_pool_project_group_body`（`hip/multihead_fast_padded.hip:424`）**本来就有 `Gout=true` 分支**（`pg_tinv(q)*N + pg_cinv(c)`，仅 6 条位运算指令）！只需在 `c512_head_group.inc` 导出 `mh_pool_project_group_c512_gout_out8`（`Gout=true, ByteOut=true`），即可在 `Down(30)` 写出 `640 KB` 1B E4M3 时直接按 ViT 顺序落盘，省掉入口 `vit_gather_b8`。
  2. **出口写入端 `Block 38`**：在 `vit_stream_project_tiles`（`hip/vit_stream.inc:66`）新增 `Gout=true` 导出 `vit_stream_project_n64_bb_bout_gout_compactw_w16`，仅在 `block == 38` 写出 `640 KB` 1B E4M3 时按 `raster(t)*1024 + ch(c)` 落盘（每个字节只写 **1 次**，L2 内完成）。下游 `Up(39)` 原封不动继续走 `decoder_project2x_h16w_byteout_w_bin` 的连续 8B/16B 合并读取！
- **物理收益**：全网每帧 kernel 发射数 **`153 → 151`**，释放 **`5.0 MiB`** `gather_maps` 显存（`gather_maps_MiB: 5.0 → 0.0`），每帧再省 **`6.4 MiB`** 显存流量，100% 逐位无损。

### 候选 3：`Down(8)`、`Down(14)`、`Down(22)`、`Down(30)`（`mh_pool_project_group_c{64,128,256,512}`）W16 FP8 WMMA + 池化去分支
- **历史误判纠正**：`2026-10-01 §9` 普查曾验证 `block{8,14,22}-ds.f32` 与 `head-matrix.f32` 权重 **100% 在 E4M3 格点上**，但误以为激活输入是 `raw`（`Hrtz`）而标为“不在格点”。实查 `mh_pool_project_group_body`（`hip/multihead_fast_padded.hip:415`）：
  `v = F(H(H(top + bottom) * .25f)); pooled[k*S + c] = (_Float16)v;`
  2×2 池化均值在写入 LDS `pooled` 之前 **已经过 `F()` 量化到了精确 E4M3 格点（且 `-0.0f` 已转 `+0.0f`）**！
- **改造方案**：
  1. `pooled` 直接存 1B E4M3（LDS 占用减半：`c512` `16.6 KB → 8.4 KB`，`c256` `8.4 KB → 4.3 KB`），`@ds-frag` 原地改为 `FragmentPackedMatrixW16` E4M3 权重；
  2. 每个 K32 `chunk` 内用 1 条 `ds_load_b128` + 4 条合并 `global_load_b128` 喂入 `wmma_f32_16x16x16_fp8_fp8_w32_gfx12`，保留每 K32 步末尾的 `acc[j][e] = H(acc[j][e] + sum[j][e])` 舍入边界，**100% 逐位等价**；
  3. 顶部 `for (uint k=0; k<16; k++)` 池化循环对内部完整 tile（`first + 15 < M && !valid_width`）走无分支快路，消除现存的 16 个循环分支。

### 候选 4：`Down(4)`（`mh_pool_project_c32_b8_out8`，`480×288`）4 列分片合波（`34,560 → 8,640` waves）+ W16 权重
- **现状病灶**：`mh_pool_project_c32_b8_out8`（`hip/multihead_fast_padded.hip:374`）每 wave 只算 16 列（`nt=4`），导致 `138,240` 个 token 发射多达 **`34,560` 个 wave**，每个 16-token 输入块被 4 个独立 wave 重复读取 4 遍，且权重 `(col+rc)*32 + half*16 + g*8` 是未分块 row-major（相邻 lane 跨 32B）；尾段还多做了一次无意义的 `acc[e] = Hrtz(0.f + sum[e])` 和双重 `q8(F(acc[e]))`（两次 `cvt_pk_fp8_f32`）。
- **改造方案**：对齐 `mh_pool_project_group`，改为每 wave 负责 16 tokens × 64 全列（`nt=1`，总 wave 数砍至 **`8,640`**），输入 `pooled` 每 wave 只读 1 次，`@ds-cast` 原地用 `FragmentPackedMatrixW16` 打包为 100% 合并 `global_load_b128`，尾段直接 `fmed3f(Hrtz(sum[e]) + 0.f, -448.f, 448.f)` + 单次 `cvt_pk_fp8_f32` 写出。

### 候选 5：融合上采样块 `UpBody`（Block 56 `C128`、Block 62 `C64`、Block 66 `C32`）上采样投影段 W16 FP8 化
- **现状病灶**：`swin_wave2_body<Up=true>`（`hip/wave_owned_mh.inc:328`）与 `cw_body<Up=true>`（`hip/wave_owned_c32.inc:223`）在 `LowByte=true` 时，仍用 8 条标量字节加载 + `cvt_f32_fp8` + `cvt_f16_f32` 构造 `h8 a`，并从**未分块 row-major `_Float16` `upw`**（跨 16 条 cache line）加载 `b` 跑 `wmma_f16`。
- **改造方案**：`block{56,62,66}-weights.f32` 矩阵区同样 100% 在 E4M3 格点上。将 `in` 改为单条 8B `i2` 加载（零转换指令），`upw` 矩阵区原地按 `FragmentPackedMatrixW16` E4M3 排列并改用 `wmma_fp8_fp8`（尾部 `upw[IC*C + ...]` skip 缩放保持 f32 不变），消除标量拆字节与跨行散读。

---

## 3. 已封板边界（禁止换名重开）

- **hipGraph 全线封板**：旧 `opt.graph=1`、外层同工 `graph0`（`ReplayOff` 161 节点）与 2026-10-14 结题的 `ReplayAuto`（162 节点强 DAG，含 `EventRecord`）在 RX 9070 XT 上均无净收益或尾延迟退步，生产维持 `EagerAuto`（`DLSS5_SUBMIT_PULSE=2, opt.graph=0`）。
- **C256 `SpStage(16,6)` / `SpStage(49,6)` 边界不动**：首尾层（`15, 22, 48, 55`）因 `Block 22` `post=3` FP32 合同、1080p `W2_FAST_NUM=3 vs 0` 数值合同差异及 `c64-wave2-fast`（LLVM23 + `W2_QKV_FUSE=3` + `W2_FFN_QT_BATCH=4`）单层核快于 COMGR 持久核，不并入 `SpStage`；`sp_init_pair` 会禁用 `submit_pulse=auto`，不启用。
- **C256 Attention W16 / C64 & C128 FFN W16**：已实测在 4/8-wave WG 屏障下打平（`+0.8 µs` / `-1~-7 µs` 噪声），不合入。
- **Uniform-SGPR `m0` `v_movrel` 转三元选择树**：已于 `isa-audit2-20261014` 实测证伪（打断 VOPD 并生成 56 条 `v_cndmask_b32_e64`，退步 `+0.14 ms`），严禁替换 uniform SGPR 相对寻址。
- **C512 块内转置 WMMA FB8（`HIP_VIT_INTER_BYTE` bit 4 = `16`）**：已实现验证逐位一致且 3/3 全胜（`-37.6 µs`），但因转置 WMMA 下 `av8` 跨 512B 访问略弱于非转置 `mode=15`（`-47.2 µs`），保留为可选诊断位，默认维持 `HIP_VIT_INTER_BYTE=15`。
- **其余 370+ 历史负账**：动手前先检索 [failed-experiments.md](failed-experiments.md)。

---

## 4. 固定工程纪律

- **GPU 锁与护栏**：所有 GPU/远程 RTC 操作必须先做 `game-check`、进程检查、确认实验盘余量 `≥100 GB`、获取原子锁 `D:\DLSSNR-Lab\gpu.lock`，并挂 15 秒游戏看门狗；游戏运行期间严禁抢占 GPU、严禁替换 DLL/HSACO。
- **数值与验收门**：结构/布局/ISA 优化必须对 `0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A` 逐位一致（`0 bit-diff`），性能只认单进程同批交错 3 轮 4-slot ABBA（`edges_only=1, NET0`）。
- **版本与仓库卫生**：commit 不加 `Co-Authored-By`；共享分支禁止 `amend`；未经用户显式指令不改动已安装游戏文件或已发布 ZIP。
