# 人物保护：时序与AMD插件接入调查

2026-10-11；本轮仅源码和官方文档调查，未下载模型、未运行GPU、未改游戏。建议先让另一组的轻量整人分割建立可靠单帧基线，再比较时序机制。全人mask可绕开“必须先检测到小脸才能保护”的瓶颈，并让脸、耳、脖、手臂共享保护规则；但小人体、低分辨率头部、遮挡和游戏画风仍可能漏分，不能把全人mask当成已解决小目标。

## 三种时序路线

| 路线 | 真正提供什么 | 当前适用位置与缺口 |
|---|---|---|
| 轻量整人分割关键帧 + 有合同的逐帧传播 | 每K帧重新确定人物，其间传播mask并检测失效 | 首选工程路线，但K不能先拍定。没有可靠MV/深度时应逐帧单图推理或短时保守降增强，不能把旧mask固定贴在画面上冒充跟踪。 |
| RVM MobileNetv3 | RGB视频→人像alpha，并循环四个时序状态；不依赖脸部检测或点击prompt | 可作“真正逐帧视频模型”的第二候选。alpha覆盖人物，非皮肤标签；衣服也会被保护。需要游戏域、小人体与多人评估，不能只用近景人像demo验收。 |
| SAM2/SAM2.1视频 | 由点/框等prompt初始化对象，随后传播多对象mask和记忆 | 适合offline难例参考/标注辅助。业务仍需自动找到要保护的人，并处理重捕获、对象选择和记忆；不作为本插件首个实时承诺。 |

RVM官方提供MobileNetv3/ResNet50及ONNX opset12，ONNX发布模型仅列CPU/CUDA测试；官方建议全身场景使用比近景人像更高的下采样比例。其104FPS数字来自GTX1080Ti、FP32、1080p、downsample_ratio=.25、batch/chunk=1的张量吞吐，不包括完整视频/插件传输，不能换算成本机AMD耗时。仓库标为GPL-3.0，后续采用需核清代码与所用权重的分发条款。[官方模型与性能范围](https://github.com/PeterL1n/RobustVideoMatting) · [论文](https://openaccess.thecvf.com/content/WACV2022/papers/Lin_Robust_High-Resolution_Video_Matting_With_Temporal_Guidance_WACV_2022_paper.pdf)

RVM必须顺序回喂四个recurrent outputs；官方文档特别指出，naive ONNX调用会把状态每帧搬回CPU，GPU绑定可避免无用传输。它不是“检测一次、后面只拷mask”；跳帧、尺寸/比例变化、切镜后的状态行为须单独测。固定输入尺寸与状态shape、GPU驻留和显式重置是部署门。[官方推理/状态文档](https://github.com/PeterL1n/RobustVideoMatting/blob/master/documentation/inference.md)

SAM2官方视频接口由prompt建立对象并维护inference state；示例采用CUDA/bfloat16，部分后处理有可选CUDA扩展。官方速度表测于A100/PyTorch2.5.1/CUDA12.4并涉及编译优化，不能直接迁移为Windows/Radeon帧时。没有在本轮验证完整DirectML导出或AMD吞吐。[官方视频接口与benchmark范围](https://github.com/facebookresearch/sam2)

## 当前源码的真实插入点

`Development/HIP/hip_reference_network.h:1030–1063` 中，`MultiPassRest`只在multi_skin且MP>1时保存**第一遍NR输出**，`BlendSkin`以original encoded输入生成mask，再混第一遍和后续多遍输出；它没有把人物恢复成游戏原图。当前MASK是每像素启发式，不是人物检测网络。资源需在producer wait之前准备；若进入graph模式，换mask来源还涉及图资源和生命周期。[多遍保护源码](../../HIP/hip_reference_network.h) · [现有skin kernel](../../../hip/multi_pass_skin.hip)

MODE3要求MP1，因此旧多遍skin hook不会自动保护MODE3。其新增修正发生于`src/native_low_frequency_shader.h`的Update分支。未来可定义保护强度P∈[0,1]：`output = normal_NR + (1-P) * extra_correction`，让脸脖共用同一人物内区权重、仅在边界羽化；不要混成“原图与增强图”，否则连普通NR去噪/修正也撤销了。这是建议接口，尚未实现。若普通NR本身已有肤色差，遮罩只能抑制进一步增强，不能自动修正该误差。[MODE3当前数学](../../../src/native_low_frequency_shader.h)

## 逐帧传播的合同

- mask须绑定原始frame ID、来源纹理、有效viewport、resize/letterbox、模型颜色预处理和时间戳。HDR线性图不应未经验证就作为训练用0..1 RGB；也不能把NR专用encoded图直接当普通sRGB。
- 若用引擎MV，需要当前→前帧方向、单位/scale、MV分辨率、jitter是否已消除、曝光/帧序与mask坐标映射；depth还需空间、reverse-Z/投影约定及遮挡/出遮挡处理。透明头发/粒子可能没有可靠MV/depth。FSR2官方也明确区分render/display MV分辨率与jitter，并对未覆盖的区域提供reactive机制。[GPUOpen合同](https://gpuopen.com/manuals/fidelityfx_sdk/techniques/super-resolution-temporal/)
- 当前low-frequency路径只有纹理格式/尺寸/scale和明确unjittered条件成立才启用MV；否则其静态回看不是已经实现的人物运动补偿。不能把这里的零位移回看直接移作人物跟踪。[现有Prepare门](../../../src/native_low_frequency_temporal.h)
- 传播置信不足、切镜、长时间缺帧、人物重现时，重检测/清状态并限制mask年龄。优先当前帧保守人物框或短时降低额外增强；不要无限拖着旧轮廓，也不要仅做未对齐mask的EMA而留下拖影。

## AMD运行与互操作成本

Windows候选首先调查ONNX Runtime DirectML：官方API能使用给定DML device与D3D12 DIRECT/COMPUTE队列，但二者必须属于同一D3D12 device。DML EP要求关闭memory pattern、使用sequential session，不能多线程同时Run同一session；固定shape有助于减少初始化与停顿。DirectML目前持续维护，新开发方向为WinML，具体版本/算子分区须实查。[官方EP配置](https://onnxruntime.ai/docs/execution-providers/DirectML-ExecutionProvider.html)

“ONNX文件存在”不等于全图GPU执行。应核算子覆盖/CPU fallback，保留输入、alpha和循环状态在GPU；D3D纹理→模型NCHW buffer仍需GPU预处理。ORT提供从D3D resource创建GPU allocation的接口，但这不是自动把现有HIP指针变成DML tensor。若mask最终在HIP多遍blend中消费，还需已验证的共享buffer与双向fence，或显式GPU拷贝；DML与NR GPU竞争、排队和持有时间都要计入。[官方DML资源接口](https://github.com/microsoft/onnxruntime/blob/main/include/onnxruntime/core/providers/dml/dml_provider_factory.h)

已有HIP NR能跑，不证明本机具备通用ONNX/CNN运行时。MIGraphX EP另需匹配的MIGraphX/ROCm栈；Windows能力须按具体发行版/显卡核验，本轮不将过时支持表或未来develop版本当本机事实。[ORT MIGraphX](https://onnxruntime.ai/docs/execution-providers/MIGraphX-ExecutionProvider.html) · [AMD Windows版本矩阵](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibilityrad/windows/windows_compatibility.html)

例如2560×1440 RGBA16F整图一次读回就是29,491,200字节；60次/秒仅这一项约1.77GB/s，还没有CPU转换、上传、alpha、循环状态和等待。这是字节预算，不是实测传输时间。应在GPU先缩放、转换与后处理，并分开记录预处理/推理/传播/混合的GPU时间及CPU排队、读回、同步的wall时间。没有本机数据前不承诺低于若干毫秒。

## 最小offline评估门（建议值，不是已测成绩）

先固定5类各5–10秒真实游戏片段：正常游玩小脸、转头/侧脸、两人交叉、遮挡后重现、快速镜头/切镜。加入至少一个逆光/发光特效难例。按脸高≤16、16–32、>32像素及人体高度分桶，不让近景平均分掩盖常见小脸；标注可见人物、脸/耳/脖内区、边界不确定区。切换附近逐帧标，平稳段稀疏标。

| 对照/指标 | 接受门与失败定义 |
|---|---|
| 单帧整人基线；关键帧K=1/2/4传播；RVM逐帧 | 先比较固定片段相同模型输入与同NR base，不能靠换曝光/场景显得稳定。SAM2仅作为额外难例参考，不能自称人工真值。 |
| 漏保护 | 每个小脸桶分别看脸/颈可见内区覆盖率；初始目标≥95%，正常可见时连续2帧漏保护即列失败案例。不能只报告整人体IoU。 |
| 跳变/重捕获 | 报逐帧FN/FP变化、连续漏帧、遮挡后重捕获帧数和mask年龄；不把真实运动造成的像素位移算成抖动。没有有效warp合同不伪报运动补偿后的稳定度。 |
| 脸脖一致与边界 | 同一人脸/颈内区平均保护权重差初始目标≤.05；检查领口、耳、手、头发边缘拖影与背景误保护。整人保护导致衣料也少增强须作为明确取舍。 |
| 输出与时间 | 同NN/同decoder记录受保护区相对普通NR的修正抑制、背景变化和人工盲看；不把mask精度当画质gold。测每阶段GPU/wall、峰值状态/缓冲、cold/warm和p95总帧增量。预算由目标帧时剩余空间决定；未达预算再比较K，不能预承诺某模型毫秒数。 |

下一步只需离线比较“可靠整人单帧基线”与一种时序方案，并验证GPU I/O/状态驻留成本；不必先把SAM视频系统移入外挂，也无需先恢复脸部检测门。
