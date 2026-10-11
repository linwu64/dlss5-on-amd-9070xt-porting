# 当前工作计划

更新：2026-10-12。此文件整份重写，只保当前状态、授权中的工作与真正未完成事项；逐轮历史见 [DevHistory.md](DevHistory.md)，负实验与旧裁决演进见 [failed-experiments.md](failed-experiments.md)。

## 当前授权：两项无损优化

用户已授权有界实际尝试，先CPU取证/证明，再按门执行真实GPU；不止于方案、不新增目标、不改变玩家默认。计划提交后建立持久隔离工作树 `/home/lmxxf/work/dlss5-bound-and-compact`，分支 `bound-and-compact`；若已有先核身份，不覆盖。实现与实验均在隔离树，主生产代码只在完整门通过、审交账后才考虑合入；部署/发包/push不在授权范围。

### A. C32 score 上界 clamp 是否严格冗余

- 先锁实际当前stock源码、有效FAST/RTZ行、产物SHA与ISA，确认目标upper clamp确实成为可删指令，不能优化未调用分支。独立audit负责证明和私有候选。
- 从**实际模型权重**、Q/K归一化、FP8量化/舍入偏置与原累加顺序给出保守严格上界；不得以理想单位范数、随机样本最大值或连续实数Cauchy上界替代实际量化链。覆盖NaN/Inf/±0/溢出和真实允许输入域；范围前提必须显式守门。
- 上界不可达证明成立才移除upper一处，保lower、score计算/映射/量化/布局与精度。证明不成立、域不足或actual ISA无可删指令即停止，保反例/资源证据，不调阈值或盲扫。
- 有效候选先最小实际unit逐bit/typedfinite与边界gold，再完整当前NN与原NativeGameFrame/HDR数值、真实mean/尾门；只有小门显示潜力才扩大正式门。样本clip为0不代证明。

### B. F32容量中FP8/F16权重紧凑存储

- remaining负责当前production实际权重live bytes、逻辑span/物理capacity、scale尾/偏移、别名与每个消费者的机器可验普查，区分仅分配富余与仍被读的F32值。保原packed bytes及精度，不重做旧VMM/arena/布局置换负账。
- 先选**一个真实矩阵**，明确紧凑buffer+scale/accessor ABI及所有引用；缺紧凑资产/未知布局/消费者不全走已验旧路或封闭拒绝，不能把旧F32指针强转后假称兼容。原权重及正常fallback不改。
- 独立CPU字节/偏移/span/alias门和双arch编译资源门后，实际unit及完整NN逐bit/finite；记录重复实例/池生命周期与首次加载、额外资产大小。
- 数值门过才测完整框架mean/尾、物理allocated bytes及可测峰值/驻留，明确driver resident与容量口径。减少容量不是减少带宽、更不是FPS收益；不从一矩阵乘层数推整网。
- 若只有静态容量节省而无速度提升，按实际收益说明，可作为资源候选而非性能成功；若额外索引/scale搬运/尾回归或兼容范围不成立，停止本候选，不无限变体。

### 共用集成与验收

- math负责共用load接口/真实整Frame caller审查与唯一GPU队列；A/B私有源互不覆盖，CPU可并行。每次actualready再交窗，不用intent占锁。
- 基线锁当前生产数学/模块/输入/权重/seed/flags、actual effective调用，不关闭已有Auto/PDL来制造优势；首尾gold、无中途图像扫描、单一有效计时范围与漂移/尾分列。微核只能筛选，不能当APP或游戏FPS。
- 每项达到证否或有效收益就交账；失败保原终态/日志/反例/数值并更新负账，成功补结果/历史/CHANGELOG。共享index轮流、源码可编译阶段及时commit，不amend、不push。

## 固定工作规矩

- 所有GPU/RTC操作先game-check、RTC/进程检查、至少100GB实验盘余量、原子 `gpu.lock`；每15秒检查游戏。游戏运行不抢GPU、不启动/结束游戏、不换DLL、不升降驱动，只继续CPU。
- watchdog仅终止本次owned PID并等待真实退出、释放自己锁；保存actual handle/PID/exit和timeout，禁止对timeout未知job重开。同handle收终态，不以SSH断开代进程完成。
- 保K累加顺序、舍入、FP8/Half编解码、NaN/±0合同。先证scope再跑；负均值/退尾不刷轮，坏event负值/近零批不计性能。
- 生产/玩家配置/安装资产保持；后续若用户另授权安装，必须具体包身份→备份→读回校验→回滚路径。只本仓工作，不改外层仓。

## 已完成且不重开的基线

- 正式0.41、tag `523723fd`、三个已上传ZIP及镜像不变；载荷源码标记 `ab8e3e82`。发布默认单遍，预测仅3x选项执行两遍+预测第三，肤色保护默认off。正式包38模块/架构、76总计，与后续本机开发载荷分开。
- 0.41后三项（final RGB免copy、block4 pool字节边、真实1440 FAST3 SP）已按各自scope完成，不跨批相加FPS；H900原布局normhoist只限已验900范围，1152尾负不启；单timed Auto提交marker已接受，不能拿pulseoff当当前APP基线。
- 当前剑星已按用户要求恢复 **MODE0/MP1/PRED0/SKIN0**，增强strength1保留但MODE0不用；最后已核addon `9413682f`、79模块与配置恢复回执见 `results/stellar-mode0-restore-20261011/`。用户观察MODE3约54fps、MODE0约58上下，非同场景ABBA，不当定量算法成本。鬼武者此前MODE1/MP1及其独立配置本轮不改，当前实际运行状态须操作前重查。
- MODE3同NN/samecodec旧HDR菜单说明修正幅度+45.2%、局部反差/颜色可辨，未证新细节/画质改善；用户未保留。skin启发式保护亦用户关闭，YuNet只单菜单demo；人物保护模型调研未选型/未游戏集成，不能列已验证小脸方案。
- ViT tile-ready `0431ba0e`已STOP：真实矩阵overlap且pair byte0，但公平GPU70.043→95.770µs、wall106.475→141.603µs，不整帧/不续变体。QKV宽尾、graph替换真实Auto产品等负账直接检索总账，不换名重复。
- current71 nativeD3D12独立分支 `b834a93f`受控185端点+final+poison全0，但GPU301–304ms对HIP约9.2ms，约33倍慢；不重启全移植，不把globalUAV桥成本归API固有差。未部署游戏。
- 完整负账 `967df5a3`，369候选分组，覆盖早HLSL/DirectML/多轮HIP/compiler/graph/interop与近期结果；以后提优化先核旧候选真实条件，修复后采纳者不能当永久失败。

## 仍未完成的其他主线（本轮不扩大）

1. **真实房顶闪烁/时序质量**：拍屏111.mp4不能替代原始连续color/MV/depth/jitter/exposure/reset。原history HALF4合同、RTZ/内部blend与受控工具链已取证，真实反光/遮挡/拖影是否改善仍未验证；不继续synthetic代真实场景，不把跳ViT删反光当无损修复。0.41-a临时历史试验默认off，正式0.41不动；资产/试包状态以各receipt为准，不沿旧“正在构建”文案。
2. **mochi差距**：旧锁定同1088/full71对照仍有约1ms量级差，但各自noise/数学/plan/输入输出边界必须分列；a9b13dd ACO同时改Linux shader、TCHAIN/weight plan，其5.7ms不是HIP换compiler可得。未有值得立即编码的泛“融合/地址外提”新刀，本轮只推进上面A/B两个具体假设。
3. **人物保护**：正常游玩小脸/脸颈一致需求保留。整人mask模型离线真游戏集、多人/遮挡/边界/时域稳定与AMD互操作成本均未验证；face parser只是第二阶段，RVM/SAM仅参考，不本轮装模型/改游戏。
4. 真实新硬件/gfx1200/game/MP3/history组合及未验导出不借其它shape门；接口源码审、单图demo或部署成功均不当性能/观感完成。需要这些现实输入时再按用户范围安排，不挤占A/B有界工作。
