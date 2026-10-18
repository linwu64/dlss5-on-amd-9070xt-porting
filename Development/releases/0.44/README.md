# 0.44 F9热修 · 2026-10-18

**最终载荷4764e4f1已装入双游戏，三包全部校验完成。** 修复《剑星》F9切模型的DirectOutput悬垂引用和deferred producer等待之后的同步上传死锁；《鬼武者》优先XboxGames配置镜像，F9立即改变内存模式，落盘失败不撤销。

同工作/有效尺寸、同时序模式保留D3D12/bridge资源；两套GPU权重与gain常驻，默认1080初始化预热Small/Original。冷模式在producer wait前预热，wait之后禁止同步Upload。SuppressFps跨重建保留；同尺寸MODE1也同时交换两模型history head、切换blend并reset。

默认0.5x、F9按0.5→1→2→3→0.5；Small的1080/900/720/free、AE和MODE1保留。80双架构模块逐SHA复用，93Small资产与旧模型共存。此前0.44的1080/900耗时5.554/4.377ms是模型基线数据，本热修不重复ABBA、不宣称新增提速。

## 正式三包

位置 `D:\給網友打包`，附`.zip.sha256`，文件名仍0.44，**按下面的新SHA辨认热修**。
公开镜像：[夸克](https://pan.quark.cn/s/ea87c0ffd257) · [Gofile](https://gofile.io/d/YCNT57JP)。

| ZIP | 字节 | SHA256 | 文件数（不含SHA256SUMS.txt） |
|---|---:|---|---:|
| Magpie-DLSS5-AMD-0.44.zip | 447,952,711 | `cf812fe7909fbd53b38f54da8abd584698525f81f7ea71cab19ba14bab48e030` | 875 |
| OptiScaler-DLSS5-AMD-0.44.zip | 478,150,706 | `40b4021ad162992ab9a4c587035ed1e821a6bd3cca7d92482514aec66218fee9` | 693 |
| OptiScaler-REFramework-DLSS5-AMD-0.44.zip | 533,121,864 | `0f10b06a73d1b683a7d95e0e3174d6c2cca1ff43c9d215a0929bf934f042927f` | 705 |

每包44项shader编译、80模块与93Small资产、ZIP逐文件回读；独立再查默认0.5/F9/HOT、Small解压流SHA、无个人配置混入；RE9包内runtime smoke exit0。GPL宿主保持aa3761f2…，配套MIT源包刷新4764e4f1并核对当前源码与ZIP内源包SHA。gfx1200继承静态模块核验，实测为gfx1201。

[当前结果](results.json) · [完整回执](receipt.json) · [源包核验](source-archive-verified.json) · [独立包内元数据](independent-package-metadata.json)。

旧正式0.44保留在 `D:\給網友打包\history\0.44-before-f9-20261018`，旧[回执](pre-f9-20261018/README.md)保留；中间6794构建保留history/0.44-f9-build1-6794c379。

## GPU与配置回归

严格空闲-idle-r3的cold/warm/AE三组受控producer栅栏测试通过，Enqueue返回时producer仍未完成；默认1080首次0.5→1与后续回环的同步Upload增量0。1080保持同一个direct输出，900重建后重新取得并实际使用新输出；全帧finite与Small往返逐位一致，SuppressFps保持。

MODE1同尺寸切换的GPU32系数与对应模型逐项一致，blend0.76708984375/0.73974609375正确切换；含history的输出与冷启动对照逐位相同。Original0900E489…与Small65D71486… Gold不变。CPU只读配置下即时和跨一秒轮询的F9循环保持，后续外部修改仍覆盖；runtime全模式与Onimusha别名进程选XboxGames镜像通过。

初轮新包装器误把game-check stdout+bool数组判真，在后台游戏仍运行时执行了测试；已立即披露、修正门禁，初轮不计验收，最终全部重新在空闲下通过。调试层不可用，验证采用真实栅栏、资源使用/读回和字节回环。[全部原始回执](../../results/f9-hotfix-20261018/README.md)。

## 双游戏部署与回滚

- 《剑星》addon SHA `4dc97d0640e0e22e54988dcca0a07d8d278165c068ce284ca975d25f35457637`。
- 《鬼武者》根目录与_storage_ runtime SHA `c10d827f20864c59926df7b5b8636b1d73178a0c76cc8ddcb53b5b485fead490`。
- 各80模块/93Small资产与shader逐文件读回；默认MP0.5/HOT1/F9，剑星MODE0、鬼武者MODE1保留。已安装runtime smoke exit0。Zero 实玩验证通过（《剑星》与《鬼武者》游戏内按 F9 切换均正常生效）。

最终备份 `D:\DLSSNR-Lab\game-install-20261018-f9fix-r3\backup-20261018-102323`；回滚 `D:\DLSSNR-Lab\game-install-20261018-f9fix-r3\rollback.ps1`。上一轮修复前完整备份仍在game-install-20261018-f9fix/backup-20261018-100728；需要回到该轮之前可用它的rollback。所有安装/测试/打包锁已释放。[最终安装回执](../../results/game-install-20261018-f9fix-r3/receipt.json)。
