# mochizuki ACO Mode：性能证据与公平比较范围

2026-10-11只读调研。官方仓`mochizuki0323/DLSSNR-AMD`，当前main/tag `v0.0.4-win-preview`锁`a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67`（commit2026-10-10 18:05:57UTC，release18:16:32UTC）。**“快很多”有作者发布的网络GPU数据，不只是网友口述；但现公开数据不足以把全部差异隔离归因于ACO编译器，也不能直接换算成我们HIP或游戏的收益。** 本轮未运行程序/GPU、安装工具、下载包/权重或改游戏。

## 实际公布的数字

[官方Windows预览release](https://github.com/mochizuki0323/DLSSNR-AMD/releases/tag/v0.0.4-win-preview)表明：RX9070XT、离线、每帧**网络GPU时间**。

| 模型分辨率标签 | Windows默认 | Windows ACO On | GPU时间差 | GPU耗时下降 | 吞吐比值On/Off |
|---|---:|---:|---:|---:|---:|
|1080p|7.21ms|5.70ms|−1.51ms|20.94%|1.2649×|
|1440p|12.59ms|9.96ms|−2.63ms|20.89%|1.2641×|
|4K|27.32ms|22.49ms|−4.83ms|17.68%|1.2148×|

耗时下降与吞吐提升不是同一百分比。release另有Linux5.60/9.70/21.89ms，以及**Linux int4 mixed**4.99/8.69/19.64ms；int4是独立低精度网络，不是Windows ACO数字。该表不是游戏FPS、不是单个kernel，也没有CPU提交完成墙钟。release感谢Windows测试者“夜空云上”，但没有附逐帧原CSV、样本数和原始bench日志供复算。

## 不是已经完成的同版本compiler-only A/B

[锁SHA的README](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/README.md#performance)明确把主体数据标为v0.0.3，int4行为v0.0.4、ACO行为v0.0.4-win-preview。因此不能自动把7.21→5.70当作同一binary只翻一个bit的受控ABBA。release也改了Windows互操作路线、驱动兼容shader写法、C512投影调度等，见[该commit说明](https://github.com/mochizuki0323/DLSSNR-AMD/commit/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67)。作者未明确给出默认行是否在新preview重新测量的原始证据；不能自行补这个协议。

更关键的是**同版本On/Off也不是同shader/同计划只换compiler**。实际代码[nr_graph.cpp](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/windows/src/core/nr_graph.cpp)中：1168附近切到`aco/shaders`（Linux网络shader）；181附近TCHAIN kinds默认Off0x1/On0x1ff；3098附近投影kernel选择分支；3221附近attention使用Npair QKV权重置换。实现审还确认采用驱动capture的PAL pipeline模板，替换离线ACO.text、SGPR适配stub与metadata再import。因此这首先是**编译代码+shader/融合计划/供数布局的组合模式**；当前不能把公开百分比标成纯ACO codegen收益。

机制上，ACO Mode0让AMD Windows驱动编译，Mode1加载包内预先编译的ACO机器码，经pipeline-binary容器进入驱动；以SPIR-V哈希选择record，不能用就记录原因并回退。它仍是Windows Vulkan计算后端，不是“把NR改成原生D3D12算子”，也不是给HIP加一个ACO优化参数。作者只在AMD Software26.9.2/9070XT测试；commit具体提驱动32.0.32015。我们此前实测32.0.31007.2048不能冒同一个已验driver build。默认0、设置1需重启；requested1不等于实际所有pipeline都导入成功，实测须审fallback日志。

## 质量与工作量不能默认为完全相同

README将NV DLL310.8.0提取的599entries/147,756,560B作为模型，包不带权重；官方[NGX verification](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/docs/ngx-verification/NGX-VERIFICATION.md)给Linux与原NV的静帧/运动序列数值证据。**这些不是Windows ACO Off/On两份逐字节gold。** README还明确Windows默认编译器与Linux存在舍入差，1080测试帧约48.5dB；不能把compiler切换天然叫无损或“更接近原版”。

公开性能表没有给出以下足以复现的字段：各分辨率实际processing/padding尺寸、ViT token数、执行node/dispatch计数、Style/seed、输入hash/格式、history/MV/reset/AE状态、warm/measure数、提交/等待协议、GPU timestamp起止代码及频率、功耗/时钟设置、每帧分布/p99。其标签是整网，但不能拿包中record数代替完整71块实际执行证明。不是说这些项一定不同，而是当前表未证明相同。

官方游戏FPS表是Linux旧0.0.1/0.0.2的不同游戏/NR前后upscale路线，不能用作Windows ACO游戏收益。新版本给NR network/route分项成本有用，但不补齐ACO on/off逐帧协议。

## 本地历史账不可偷换

生产DevHistory已查：旧mochi实测锁`d1185d25141b...`/v0.0.2.5，而本地更旧ACO源码`4f62a8a...`并不是当时测速版本。旧同640token差约1.046ms的账，与现在v0.0.4 preview5.70ms是不同版本/协议；不能以新数字倒推旧测用了ACO，也不能将这项delta直接扣到我们HIP。我们的最新原生D3D12移植约301–304ms仍是global-UAV fragment桥等成本很重的实现；作者表从7.21ms出发的约18–21%耗时降低，不能解释或自动修复这项移植差距。

## 若下一步与当前HIP验证，最少需要的具体合同

先在**同一新版mochi程序**里切ACO0/1，确认实际import/fallback和driver/GPU身份，测清组合模式收益，再谈跨HIP。若要进一步隔离compiler，必须另锁相同SPV、shader plan、chain flags、weight变换与grid；默认开关本身做不到这点：

1. 源SHA、Windows包/实际程序SHA、相匹配的SPV与ACO records及pipeline key集合、真实驱动文件版本与GPU UUID；不只看INI值。不要在游戏里试，也不为了试验盲升降驱动。
2. 同一NV310.8.0提取模型与SHA、同Style/seed/完整71块/MP1/AE0/historyoff；int4明确关闭。先打印实际几何/ViT tokens/dispatch，而不是将“1080p”自动当我们1920×1152/640tokens。
3. 复用当前HIP受控encodedRGBA32F输入`b3d114c4779fc1f593162b36d22bbb5ae7777e22e7aec701f0f551916539b2ac`，把色域、预编码、noise生成位置和输入padding锁定。新版M的输入接口/计划若不同，先建立等价转换与捕获证据，不硬塞后声称samework。
4. 每variant先finite/repeat及实际输出误差；ACO0/1若不同，报告变化量/原NV参考误差，不要求假跨实现bit0。HIP canonical PDL0与production-selector PDL1分列，不能把BridgeAuto2/游戏互操作算进pureNN。
5. 同设备空闲窗口下先HNNH/ABBA小筛，warm/样本数、GPU整网outer与CPUrecord/submit/fence墙钟分列，首尾raw与source/weight identities保留。若要比较APP/游戏，则另量两后端实际interop/codec，不叠加纯NN百分比。

这是后续可判的最小设计，不是已授权/已执行的测试。当前结论：**ACO组合模式值得研究的实据是作者RX9070XT上约18–21%整网GPU耗时下降；同版本开关仍同时改变shader/计划，纯compiler归因与我们当前HIP的可比收益尚未建立。**

## 已核primary来源

- [v0.0.4-win-preview release与原数字](https://github.com/mochizuki0323/DLSSNR-AMD/releases/tag/v0.0.4-win-preview)
- [a9b13dd4...完整commit：兼容修正、binary导入、驱动与检查scope](https://github.com/mochizuki0323/DLSSNR-AMD/commit/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67)
- [固定SHA README：版本标签、Performance、Windows ACO、模型与质量声明](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/README.md)
- [NGX数值验证文档，不能代Windows ACO A/B](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/docs/ngx-verification/NGX-VERIFICATION.md)

另只读GitHub API查了当前11commit、10release及issues API的6项列表/正文（其中1项是PR）；未发现作者另发ACO逐帧原CSV/受控bench协议。该结论限此仓当前公开内容，不排除作者私下或其他渠道有更多数据。本轮未抓取网友视频/传闻当原始测量。
