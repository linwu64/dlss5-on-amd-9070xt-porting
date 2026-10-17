# 0.5x Small：5090 Oracle、权重转换与HIP 1080阶段回执

2026-10-18；基于 `3a04bcf0` / 已发布0.43载荷 `10982cf4`。**本次交付1080档阶段闭环；900/720/free与Small原生history仍待后续，不称全分辨率发布完成。** 没有改已装《剑星》《鬼武者》、0.43 ZIP或上传发布。

## 产品与执行图

- `DLSS5_MULTI_PASS=0.5` 为源码与三个模板的新默认，名称 **0.5x**；执行一次31块Small。`1` / `2` / `3` 仍为旧71块单遍/叠层；3x的预测开关保持原语义。
- add-on 的F9顺序为 `0.5 → 1 → 2 → 3 → 0.5`。模式身份与整数遍数分开，避免把0.5截断成0遍。热重载实际写入字符串`0.5`；日志记录requested/effective。
- Small权重在资产根目录的`small/`，旧权重保留在根目录。逻辑31块ID与既有kernel-role文件名通过manifest映射。完整/缺失/错误尺寸及f32优先于f16的检查在CPU测试通过；缺资产真机请求0.5日志回退1x，输出与显式1x逐位相同。
- 1080图执行角色为 `0,1,4,5,8,9,14,15,22,23,30,31..38,39,40,47,48,55,56,61,62,65,66,69,70`，实际31块；encoder各对shift 0/3，decoder各对1/2，Post3。六skip沿原算子合同恢复；详前一份[逆向报告](../dlssnr-310-9-16-analysis-20261018/README.md)。
- 复用现有已验证HIP算子与80个双架构模块，没有重编/替换HSACO；保留F16 C32 Up，不引入已失败的FP8 Up候选。Small禁用旧图专用SP/Pulse/PDL提交和自适应ViT复用。
- 跨模型切换前drain并清理图、权重、SP计划中的权重裸指针、PDL前驱引用及自适应状态；Original 1/2/3之间保留同模型权重与计划，避免无谓重载。9070上真实跑过0.5→1→2→3→0.5，Small往返输出bit-diff=0；最终生产SP与默认第三遍预测组合还验证了所有模式有限、热1x=冷1x、Small往返bit0，见[mode-roundtrip.json](mode-roundtrip.json)；F9配置写回/优先级与reload另由Windows CPU测试验证。未冒称在已安装游戏里按过F9。

## 权重转换

转换器：[convert_weights.py](../../HIP/experiments/small-model/convert_weights.py)。输入只接受新DLL完整SHA `2bc19bc09a7b89dd44f73e2ac0108fcc586e2154bdd0830f242f4f040e28789f`，依据已实读资源偏移取原字节，复用本仓basis恢复的布局解码器；不是把mochi的canonical矩阵直接当本仓通道顺序。

- 用同一转换器先重解旧HT：**184个主图权重与现有完整HIP资产逐float bit一致**，再生成Small。
- Small **93个权重文件，241,214,392 B**：92个主图资产+64B的`post70-history-head.f16`。半精度能无损往返才写f16，否则保留f32；不额外量化。全部名称、元素数、文件SHA与逻辑f32 SHA见[manifest](model-manifest-small.json)。
- Small的blend保存为half `0x3A23` / `0.76708984375`，history行6 SHA `c4c5f5189360756001e96abb43a482396ac8bde56f6ac4c7c19ae63db01d0980`。该辅助头已转换，Small原生history消费尚未接通/验收；不拿“文件存在”当时序通过。
- 转换产物：Linux `/home/lmxxf/work/dlss5-small-build/small/`；9070 `D:\DLSSNR-Lab\small-model-20261018\assets\small\`。大二进制留外部实验目录，不进Git。manifest中的`gpu_validated=false`表示转换器本身不作GPU声明，本回执独立记录后续验证。

## 5090独立Oracle

实际机器`ssh rtx5090` / RTX5090，NGX日志驱动616.92，615核心API0x15；新旧DLL均通过NGX完整Create/Evaluate，非CPU模拟网络。实验在`C:\DLSSNR-Small-20261018`；D盘仅63GB，因此改用余量约777GB的C盘，锁仍在约定的D盘位置。固定Style1、reset1、history off、seed0，两个输入文件分别运行两次。

1. 无hook版本先保存API最终RGB32F：新DLL Preset1=旧DLL310.8；Preset0=Preset2。合成输入与两张真实8678/8680均成立；相同帧重复逐字节稳定。
2. 只读参数观测与内部Post捕获分开运行。前端hook/捕获前后，各API最终输出哈希逐一一致，证明诊断未改变最终网络结果；输入纹理捕获与上传半精度输入逐值一致。
3. **API最终输出与内部Post不是同一比较域。** API有额外合成，直接拿它比HIP网络RGB头得到约25dB的首轮结果不作为模型接入验收；本次HIP数值对账使用原网络Post内部FP16 surface朝零存储后的RGB，仅half→float展开。它不是pre-half RGB32F，也不宣称HIP逐位等于NGX最终API。
4. 新DLL pre参数由264B变272B，尾部控制/seed/几何字段有位移；Post仍184B。诊断源码按两份已核DLL的backend RVA区分，未把旧RVA生套新DLL。完整实际参数与kernel序列在[oracle](oracle/)各`launch-observe.txt`；无hook/捕获API hash也在该目录。

真实8678帧对内部Post，Style1/seed0/history0：

|模型|HIP算术|PSNR|MAE|
|---|---|---:|---:|
|Original 1x|FAST_NUMERIC=0|42.966729 dB|0.005057259|
|Original 1x|FAST_NUMERIC=1|41.414972 dB|0.005885195|
|Small 0.5x|FAST_NUMERIC=0|48.021703 dB|0.002913497|
|Small 0.5x|FAST_NUMERIC=1|47.755055 dB|0.003008362|

真实8680的Small FAST1为 **46.862705dB**；两帧均有限、输入捕获diff=0。完整指标、输入捕获diff、实际原始文件路径/SHA见[oracle-quality.json](oracle-quality.json)。这是现有近似HIP算术对独立NVIDIA的逐值测量，**不属于NVIDIA 0 bit-diff声明**；也不能把两份不同训练模型各自PSNR的差值当画质评分。

## 1080 Gold与单帧耗时

完整NativeGameFrame，1296×720冻结真实HDR输入，1080档1920×1152 / 640 tokens，FAST_NUMERIC1、NET0、history/AE/skin/predict关、graph0、默认模块。Gold及每个ABBA槽核验首尾输出有限且重复，Original始终冻结旧gold：

- Original：`0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A`
- Small：`65D71486636715598EE1994166D5186A52D5F53230DBD7F8F03E514E3EC8FCB8`

3轮4-slot **1x / 0.5x / 0.5x / 1x**，每槽240帧、丢前80帧，`edges_only=1`，每角色合计960稳态样本：

|轮次|1x mean|0.5x mean|Δmean|
|---|---:|---:|---:|
|R1|9.126542 ms|5.536965 ms|-3.589577 ms|
|R2|9.160444 ms|5.556997 ms|-3.603447 ms|
|R3|9.181475 ms|5.566567 ms|-3.614907 ms|

Pooled mean：**1x 9.156154 → 0.5x 5.553510 ms/frame**，耗时减少**39.347%**，同批速度比1.649×。Small median 5.535300ms、p99 5.820500ms；1x p99 9.374200ms。对0.43历史9.121ms，Small约少39.113%，主要结论采用同批ABBA。

原CSV/flags/host日志与每轮gold见[frame](frame/)，汇总见[performance.json](performance.json)。驻留权重上传容量297,609,000→154,793,464 B（184→92个主图权重）；不是整进程VRAM峰值。冷启动上传与编译耗时不计入稳态帧时；没有把Gold首帧的一秒初始化混入性能结论。

## 构建、护栏与下一段

- [构建/源码指纹](build-provenance.json)与最终宿主Gold回读已落盘；[93项资产](small-assets-readback.json)与[80模块](module-readback.json)全部实际SHA核对通过。add-on、runtime和完整frame host均Linux交叉编译通过；模块沿用0.43已验证双架构80文件。此阶段没有对gfx1200执行Small真机验证，也没有游戏部署、RE9游戏实玩或重新打包发布。
- 所有GPU任务先game-check、实验盘余量≥100GB、原子`D:\DLSSNR-Lab\gpu.lock`，执行中15秒检查游戏，超时只终止自己的子进程；任务结束释放锁。原始GPU大数据与二进制在上述两台实验目录及Linux工作目录。
- 本次为**1080阶段**：900需1600×1024/448token、720需1344×768/288token，尚需实现逐层ceil-half/round4及外层缓冲几何重建，不能只换height。当前这两档与free显式日志回退Original 1x。
- Small原生history/gate/0x3A23的时序消费、AE新gain与其它可选优化仍为独立后续门；当前相关native-history消费者回退Original，辅助权重虽已生成不等于已接通。
- 下一步先900/720逐节点几何与Oracle，再验证跨尺寸热切换、原生时序及多帧/真实游戏体验，并把F9/热重载扩展到runtime（当前仅add-on；runtime在创建时读0.5配置），之后才准备新的发行包。

复现脚本：[run-oracle.ps1](../../HIP/experiments/small-model/run-oracle.ps1)、[run-hip.ps1](../../HIP/experiments/small-model/run-hip.ps1)、[run-frame.ps1](../../HIP/experiments/small-model/run-frame.ps1)。这些脚本只操作隔离实验目录，按参数创建新case，保留历史回执。

回执文本统一为UTF-8/LF并去行尾空白；二进制输出/权重/模块的SHA仍为实际文件读回值。
