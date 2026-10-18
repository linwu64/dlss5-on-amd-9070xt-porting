# 0.44 · 2026-10-18

**正式三包已完成并校验，双游戏已部署默认0.5x。** 载荷源码 `b8f762387ecac928f935f89a89461a41214b2421`（功能提交8e8ff1f4）；实际80模块来自已验10982cf4，逐SHA复用。

Small 31块新模型支持1080/900/720/free，AE按8个ViT块算gain，MODE1使用新head及0x3A23。F9按0.5→1→2→3→0.5循环，2x/3x暂挂MODE1再恢复；缺Small资产记录日志回退1x。93个Small权重与旧71块资产共存。

RX9070XT完整帧回放：1080档 **5.553510ms/frame**（前阶段三轮，−39.35%）；900档 **4.376946ms/frame**（本阶段三轮，同批1x6.558681，−33.26%）。Small是不同训练模型，默认输出改变；900/720对5090内部Post为47.40/47.70dB，不称NV逐位一致。[全部数值/性能/时序回执](../../../results/small-complete-20261018/README.md)。

## 正式包

位置 `D:\給網友打包`，每包附同名`.zip.sha256`。公开上传尚未执行。

| ZIP | 字节 | SHA256 | 包内文件（不含SHA256SUMS.txt） |
|---|---:|---|---:|
| Magpie-DLSS5-AMD-0.44.zip | 447,953,583 | `57e6bd49d0becffe0929f5a5e5c7e1e64deacbec5fa20f9a7c3082715df23cf9` | 875 |
| OptiScaler-DLSS5-AMD-0.44.zip | 478,151,601 | `452538281833634a71b530423ef440436e7644aca8f821ec91ecf9d09f8939e7` | 693 |
| OptiScaler-REFramework-DLSS5-AMD-0.44.zip | 533,119,059 | `e501bbd3323b8fadea1819c301e1843a672a57d2a4f88548015e98eaef1316cd` | 705 |

每包44项生产D3DCompiler shader编译、全ZIP逐文件回读、80模块及93 Small权重SHA检查全部通过；独立再次检查默认0.5/F9/HOT、无个人配置混入、Small逐文件解压流SHA。REFramework包内runtime GPU smoke exit0。GPL宿主未改，配套源包已刷新当前MIT核/runtime，压缩源包逐SHA核验通过。Shader保留既有EffectivePaperWhite编译警告；未产生编译失败。

- [正式结果](results.json) / [发行回执](receipt.json) / [独立包内元数据](independent-package-metadata.json)。
- [源包当前源码核验](source-archive-verified.json) / [ZIP内源包核验](zip-source-verified.json)。
- 原始Windows混合代码页控制台日志留远端，本仓日志转UTF8；乱码只涉及控制台路径，数值与JSON回执独立保存。

## 双游戏安装

《剑星》addon SHA `0f4bcf62cf99dcc992f52372d941168ad1085b4aa1d27f722c760d12536046f5`；《鬼武者》根目录及_storage_ runtime SHA `ced2df192ab7d433da26f1c4f5160e312547e49b73529bd1adeff92832a486dd`。两者各80模块/93 Small权重，配置三层MP均0.5；custom/native均HOT1/F9。《剑星》保持MODE0，《鬼武者》保持MODE1。更新与备份逐文件读回；已安装鬼武者runtime实际执行Small且smoke exit0。没有替Zero启动游戏实玩。

备份 `D:\DLSSNR-Lab\game-install-20261018\backup-20261018-050250`；回滚脚本 `D:\DLSSNR-Lab\game-install-20261018\rollback.ps1`。每个修改/新增文件都有manifest记录，回滚逐文件恢复原字节或删除新文件。原子gpu.lock与15秒game-check全程启用，最终锁已释放。[安装回执及回滚](../../../results/game-install-20261018/receipt.json)。
