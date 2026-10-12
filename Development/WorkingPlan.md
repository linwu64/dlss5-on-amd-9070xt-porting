# 当前工作计划

更新：2026-10-12。本轮三项已结题，源码、构建与数值证据交付完成；没有下一项优化或GPU排队。起点 `abacaaed`（`5574d8db`试用、`1b4c898f`此前expand紧凑源码），计划 `ec0a2e99`，持久实验树 `/home/lmxxf/work/dlss5-resource-followups`。历史见 [DevHistory.md](DevHistory.md)，负账见 [failed-experiments.md](failed-experiments.md)。

## 三项最终裁决

1. **无history会话：采纳。** 显式NeverHistory，公共unknown默认保旧，所有temporal入口拒违反，不热分配。43364完整Framegold0，fresh会话实际少一项35389440B=33.75MiB共享buffer/导入，candidate创建2/import2/poolhits0；driverfree另录+67.5MiB，不解释为物理双份或峰值。36250 Framewall微+3.596µs，小于26.392µs控制漂移，无稳定加速。DirectHistory/实验/未声明会话保旧。
2. **C512未用mixed/contract：停止、撤回。** 26032实际48calls/fallback0/gold0，但best-fit池290571128→292742008B反增2170880B，driverfree仅+64KiB，逻辑少New未带来净省。a5786fbb已恢复共享原两New；不perf、不调池，候选与原负证保留。
3. **ViT活scale尾紧凑：contract与projection均采纳资源收益。** 仅搬原packed字节与4096B F32尾、改变新export尾地址，精度/math/累加顺序不动。contract79561实省96MiB，projection11819在已启contract上实省24MiB；两轮ABBA均值变化−8.569/−1.756µs均低于控制漂移46.113/26.492µs，不宣提速，单max分别+0.258/+0.187ms保留。最终生产同宿主66725/两43模块旧新路径gold0：weights423438120→297609000B净省120MiB，history0，8+8新keys，无侧车/NR实验开关。

## 最终源码与边界

- 默认内部紧凑开关只在已审gfx1201/RX9070XT、1152固定profile及正确byte-edge消费者生效；未知selector、自定义模块、缺新export/已有legacy cache保持旧buffer+旧kernel成对，gfx1200保旧，不宣双架构实机验证。官方既有vit_stream recipe自然构建两newexport，不增加永久模块或用户配置。
- 最终正式Frame宿主O2 99541=0、addonO2 30670=0，jointCOMGR94285=0；旧86个及两accepted候选87个函数对joint均逐原始函数字节一致。实际emitted helper CPU default1/off/unknown/cache/layout兼容门通过；正式66725全帧firstlast0900/finite/Auto3/原模块身份与旧模块fallback通过。证据索引 [resource-followups](HIP/experiments/resource-followups/README.md)。
- **游戏里仍是已安装64dc/原MODE0/MP1/1x，正式0.41不变。本次33.75MiB共享资源与新增120MiB权重减少尚未部署到游戏，未push。** 先前expand已省96MiB包含在本轮基线中，不能重复报作新收益；用户58.2fps是此前现场观察，不是这些新改动的性能证据。分配宽度、driverfree快照、驻留峰值严格分列，三轮性能不相加。

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
2. **mochi差距**：旧锁定同1088/full71对照仍有约1ms量级差，但各自noise/数学/plan/输入输出边界必须分列；a9b13dd ACO同时改Linux shader、TCHAIN/weight plan，其5.7ms不是HIP换compiler可得。未有值得立即编码的泛“融合/地址外提”新刀，本轮资源三项已结题；未追加新的实现任务。
3. **人物保护**：正常游玩小脸/脸颈一致需求保留。整人mask模型离线真游戏集、多人/遮挡/边界/时域稳定与AMD互操作成本均未验证；face parser只是第二阶段，RVM/SAM仅参考，不本轮装模型/改游戏。
4. 真实新硬件/gfx1200/game/MP3/history组合及未验导出不借其它shape门；接口源码审、单图demo或部署成功均不当性能/观感完成。需要这些现实输入时再按用户范围安排，本轮没有为此追加实验。

## 2026-10-12 本机试用更新

剑星已按授权安装紧凑权重正式O2 addon `64dc04286c22d5d3…`（源码 `1b4c898f`，部署57883 exit0）；MODE0/MP1/PRED0/SKIN0及其他配置字节不变，模块/Runtime不变。用户可启动试用；游戏观感/帧率尚未测，不当新发版。回执与回滚：`results/stellar-compact-trial-20261012/`。

- 2026-10-12 12:54 用户反馈“有提升”，通过Splashtop玩剑星，用户原称“2k AA(1080P dlss5) exact”，静态画面稳定58.2帧；对应addon `64dc04286c22d5d3…`，MODE0/1x设置未改。属实玩观察，旧版无同场景精确对照，不报精确增幅。
