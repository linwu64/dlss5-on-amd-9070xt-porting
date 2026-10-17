# Small 第三阶段：全档几何、AE、时序与0.44

900/720/free原生几何、Small自适应复用与MODE1已接入；正式宿主构建完成。双游戏部署与发行包结果另见 `Development/releases/0.44/README.md` 和安装回执。

## 几何与数值

逐层使用 `round4(ceil(n/2))`。900有效1600×900，处理1600×1024，C512 52×32，ViT 28×16=448；720有效1280×720，处理1344×768，ViT24×12=288。free 1001×777映射处理1024×832，ViT16×16；2560×1440映射2560×1472，ViT40×24。边界输入与输出分别按valid/work宽度索引，新增X反射补边。跨模式重建整条帧资源和history，跨尺寸由Runtime重新绑定资源。

5090真实输入8678、Style1、seed0、historyoff、FAST1，HIP NN RGB与NV内部Post FP16（扩为float32）对账：900 **47.402599 dB**，720 **47.702756 dB**，无全RGB零像素。不是API最终合成输出，也不是NVIDIA逐位一致。原始图像保留在外部工作目录，SHA见oracle-quality.json。四组Preset1/2/default作业各两帧，Preset1旧图、default=Preset2新图。

720初始捕获缺少UAV屏障导致底部随机零块。捕获器在Post抓取前后补全局UAV barrier后重抓；四组API最终输出SHA均未改变，说明修正的是裁判读回同步。900旧抓取无零块，保留原回执并注明没有新增屏障。

最终1080整帧4-slot Gold：Original `0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A`；Small `65D71486636715598EE1994166D5186A52D5F53230DBD7F8F03E514E3EC8FCB8`。900/720分别建立同模型首尾/重复进程Gold，均finite和逐位可复现。

## RX9070XT耗时

900档3轮4-slot ABBA，单进程240帧、丢弃80帧，每种模型合计960稳态样本。Original处理1600×960，Small按NV新模型规则处理1600×1024。测量含完整编码/网络/解码，AE0/MODE0/FAST1/NET0/edges_only1。

| 轮次 | Original ms/frame | Small ms/frame | 差值 ms |
|---|---:|---:|---:|
| 1 | 6.526635 | 4.368573 | −2.158062 |
| 2 | 6.572470 | 4.381562 | −2.190908 |
| 3 | 6.576937 | 4.380703 | −2.196234 |
| pooled | 6.558681 | **4.376946** | **−2.181735 / −33.2648%** |

Small median4.367150，p99 4.6548；Original median6.5474，p99 6.7955。1080沿用阶段二5.553510ms（−39.35%）；720未做正式性能ABBA，不给产品耗时承诺。gfx1200仅模块静态核验，真机测量均gfx1201。80模块逐SHA复用，宿主与边界shader更新。

## AE与时序

- Small AE从逻辑11..18（兼容资产角色31..38）的8个ViT权重计算gain，禁用旧gain文件捷径；F8保留AE/EXACT切换。MODE1和多遍沿用禁止AE复用的现有策略。
- Small独立post70-history-head.f16和blend半精度0x3A23=0.76708984375；Original仍0x39EB。共用96字节参数ABI，保留真实motion标记。
- GPU解析例验证12有效列/16处理列，logit0的权重计算输出0.569873035；填充区也一致。
- 完整720 MODE1 12帧与第6帧reset回环逐位一致；0.5→1→2→3→0.5回环Small第0/8帧一致；2x/3x临时挂起MODE1，回到0.5/1x恢复。
- AE与free完整帧各12帧finite。所有GPU作业均game-check、原子gpu.lock和15秒看门狗；锁已释放。

实验代码在 `Development/HIP/experiments/small-model/`，CSV/flags/stdout/stderr与SHA在本目录。外部大载荷在 `/home/lmxxf/work/dlss5-small-build` 与 `D:\DLSSNR-Lab\small-model-20261018`，不入Git。

Runtime DLL完整路径追加验收：同一会话MODE1/free依次1280×720→1600×900→1001×777→1280×720，每尺寸4帧，全部完成；首末相同尺寸输出hash一致。另1024×832非固定档Small raw路径3帧finite/完成。r3误读D盘实验根的旧flags导致回退1x，不能用作Small验收；r4使用独立正式模板布局，日志四次effective=0.5x且skip=0。初两次runtime实验仅因lab未放codec shader未能启动，补齐正式布局后通过，未修改网络数值。
