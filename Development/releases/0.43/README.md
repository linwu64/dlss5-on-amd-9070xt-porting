# 正式 0.43 本地三包（2026-10-17）

载荷源码 `10982cf4`，复用此前验收完成的 addon/runtime 与双架构80模块，以完整0.42 ZIP为基底。未重跑模块编译或ABBA；0.42原包保留。本轮只打包和验证，没有再次修改游戏或玩家配置，也没有公开上传、push、tag或GitHub Release。

## 成品与SHA256

目录：`D:\給網友打包`，每个ZIP旁有同名 `.zip.sha256`。

|文件|字节数|载荷文件数（另含总SHA清单）|SHA256|
|---|---:|---:|---|
|`Magpie-DLSS5-AMD-0.43.zip`|345,297,302|781|`b3450315de6bf23bfbbd550a56cc82d7ed461e31b6a2c402e6baf1fefe3160ac`|
|`OptiScaler-DLSS5-AMD-0.43.zip`|375,495,322|599|`e507a6b4fb4e8a80c92334f7509d40f81907095eb6b281190d8c09756e4e512e`|
|`OptiScaler-REFramework-DLSS5-AMD-0.43.zip`|430,517,634|608|`0ac552c469f7d4b88dbb0e3d7aa484e462a5fd4967d8f52b6d29adbc5257203f`|

## 内容与默认

- 包含10-14已采纳的W16权重/ISA/字节流优化、MODE2/3有界资源环，以及10-17验收收下的decoder字节边/W16 FP8与grouped Down字节LDS/W16 FP8。
- 默认MODE0/MP1/PRED1/SKIN0；预测只在选3x时使用，PRED0保真三遍。Magpie保持MODE0，不宣称已接入新增时域消费者。包内没有玩家custom-config.txt/native-game-flags.txt；升级保留个人覆盖。
- 新addon SHA256 `2cefc60d50906d9a5dcf542f1c890819fcaa01b2d712047423d303b8f0475e5b`；runtime `bc7b77049f828e1500bfe447d9f09c963b38b2c5584c104f65650e5127f8decd`。RE9的GPL OptiScaler host保持0.42的 `aa3761f2cdb0d9a4653732bd430019ff421b3ce9471fe3697b553dc6d71714a2`。
- 80模块逐SHA与此前已验载荷一致，包含修正后实际gfx1200 ELF目标；gfx1200仍仅编译/ELF核验，不冒真机证据。10-17固定配置Gold与性能原证见[最终载荷验收](../../results/five-final-20261017/README.md)，不把它当0.42→0.43总FPS增幅；其中1080一轮p99回退原样保留。
- GPL宿主源码保持原锁定版本，附件 `sources/re9-presr-source.tar.gz` 刷新MIT核心与当前打包说明，嵌入10982cf4来源标识；未重编宿主。源码附件SHA已从ZIP内独立读回核对，见source-archive-verified.json与source-refresh.json。许可及依赖文件保留。

## 验证结果

1. 每包44项shader变体编译通过，共3组；原stdout/stderr保留。
2. RE9包内runtime-smoke：PrepareFrame rc=0、HIP rc=0、SP_STATS errors=0、lmxxf_nr_gpu: ok，exit0。这是包内API冒烟，不冒充真实RE9游戏观感。
3. 三个ZIP逐文件SHA回读通过；无重复或额外条目。旁置.zip.sha256与实际ZIP一致。
4. 独立核对版本、来源、默认配置、80模块身份、history row、宿主SHA、无私人配置/实验侧车；与本地已验模块清单及10-17安装回执再次逐项匹配。
5. GPU相关打包步骤使用game-check、≥100GB磁盘余量、原子gpu.lock和15秒游戏看门狗；最终锁已释放。无模块RTC编译/性能复跑。

初始准备阶段的重复展开配置包与PowerShell5 UTF-8无BOM路径解析失败发生在成包前，修正为幂等展开及带BOM脚本。原失败日志保留；独立metadata输出指定UTF-8。没有删掉失败轮，也没有复刷性能数据。

## 回执与后续

`results.json`：三个成品；`receipt.json`：总回执；`independent-package-metadata.json`：ZIP结构/默认/模块/宿主核对；`HIP-SHA256SUMS`：复用80模块；`package.stdout.log`/`package.stderr.log`：原验证日志。入口为 `Development/tools/package-043.ps1` 与本目录stage/run-package/verify-packages/verify-source脚本。

本机双游戏由鳩先行安装10982cf4，备份、配置保留、读回与smoke回执在[game-install-20261017](../../results/game-install-20261017/README.md)，本次一并入库。旧“be506729稳定60fps”为历史用户观察，不移作新包FPS验证。

## 用户提供的公开镜像（2026-10-18）

[夸克](https://pan.quark.cn/s/3b19c0403e3f) · [Gofile](https://gofile.io/d/hz5cDOPF)（三个 0.43 完整包）。链接由用户提供；本地 ZIP、二进制与记录的 SHA-256 保持不变。单帧耗时基准（RX 9070 XT `frame.exe` 稳态均值）：1080 档 `9.121 ms`（最佳单槽 `8.960 ms`）、900 档 `6.535 ms`。
