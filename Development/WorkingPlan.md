# 当前工作计划

更新：2026-10-12。此文件整份重写，只保当前状态、授权中的工作与真正未完成事项；逐轮历史见 [DevHistory.md](DevHistory.md)，负实验与旧裁决演进见 [failed-experiments.md](failed-experiments.md)。

## 两项优化已结题（2026-10-12）

持久隔离树 `/home/lmxxf/work/dlss5-bound-and-compact` / `bound-and-compact` 保存源、证明和实际终态。无新 GPU 排队，不追加变体；未部署、未 push，正式 0.41 和玩家 MODE0 配置不变。

- **A，C32 score upper clamp：正确但未采纳。** 实际十层权重仅七层获严格界，后三层保持 stock；65536 Half 位型×32位置原语、真实 mapped unit、三帧完整 Frame 与七/三实际路由全部通过。单次完整 Frame ABBA25355（每槽320帧、弃80）wall 9.6336771→9.6284083 ms，仅−5.269µs；基线漂移+47.546µs，不能确认稳定收益。停止，不将 NoHi 加入生产路径。详见 `HIP/experiments/c32-score-nohi/` 与失败总账。
- **B，八个 ViT expand packed 权重：作为资源优化集成。** 完整 Frame 逐字节相同，持有权重容量 524101416→423438120B，实省96MiB；单次 ABBA wall 9.633050→9.6346917ms，无稳定速度收益。仅精确已知八矩阵/布局缩短上传，未知 selector 和已有 legacy key 保留旧路，默认狭域开启、编译宏可关闭。容量/driverfree 快照不是驻留峰值，未做双架构实机验证。源码与证据见 `HIP/experiments/packed-weight-compact/`。

本轮源码、文档与证据已审交结题；未追加任务或性能实验。真实运动闪烁、mochi 与当前生产路线差距仍是未完成研究；先取有决策价值的证据，不能重开 [failed-experiments.md](failed-experiments.md) 已否定的 tile-ready0431、宽写、graph Auto 替换或 native D3D12约33倍慢路线。MODE0约58fps是用户观察，不是同场景ABBA。

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
2. **mochi差距**：旧锁定同1088/full71对照仍有约1ms量级差，但各自noise/数学/plan/输入输出边界必须分列；a9b13dd ACO同时改Linux shader、TCHAIN/weight plan，其5.7ms不是HIP换compiler可得。未有值得立即编码的泛“融合/地址外提”新刀，本轮A/B两个具体假设已结题；未追加新的实现任务。
3. **人物保护**：正常游玩小脸/脸颈一致需求保留。整人mask模型离线真游戏集、多人/遮挡/边界/时域稳定与AMD互操作成本均未验证；face parser只是第二阶段，RVM/SAM仅参考，不本轮装模型/改游戏。
4. 真实新硬件/gfx1200/game/MP3/history组合及未验导出不借其它shape门；接口源码审、单图demo或部署成功均不当性能/观感完成。需要这些现实输入时再按用户范围安排，本轮没有为此追加实验。

## 2026-10-12 本机试用更新

剑星已按授权安装紧凑权重正式O2 addon `64dc04286c22d5d3…`（源码 `1b4c898f`，部署57883 exit0）；MODE0/MP1/PRED0/SKIN0及其他配置字节不变，模块/Runtime不变。用户可启动试用；游戏观感/帧率尚未测，不当新发版。回执与回滚：`results/stellar-compact-trial-20261012/`。

- 2026-10-12 12:54 用户反馈“有提升”，通过Splashtop玩剑星，用户原称“2k AA(1080P dlss5) exact”，静态画面稳定58.2帧；对应addon `64dc04286c22d5d3…`，MODE0/1x设置未改。属实玩观察，旧版无同场景精确对照，不报精确增幅。
