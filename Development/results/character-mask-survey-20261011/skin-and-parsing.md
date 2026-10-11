# 脸、脖子、耳朵与裸露手臂的一致保护：模型调研

2026-10-11，仅核官方论文、作者代码/模型发布及平台文档；未下载权重、安装依赖、跑GPU或改游戏。结论：**没有核到一个既轻量、已验证AMD游戏小脸、多人物，又明确独立标注脸/颈/耳/手臂的现成全图模型。** Face parsing的颈耳标签最直接，但不管手臂；human parsing能借身体上下文避开“先检出脸”这道门，却不意味着颈耳的标签定义齐全。不能用一次菜单近脸成功，替代正常距离游戏验证。

目前MODE3/MP1没有旧多遍肤色保护hook。若以后接MODE3，建议只抑新增修正：`base + (1-mask)*delta3`；若接多遍，仍是`mask*firstNR + (1-mask)*lastNR`。两者都不是把人物替回原游戏画面。本文件只研究模型，不提出已实现的功能。

## 三个候选，先核标签

| 候选 | 已核预训练与输入 | 脸/脖/耳/臂/手覆盖 | 整图与多人、小脸 | 获取与部署成本 |
|---|---|---|---|---|
| SCHP，LIP或ATR权重 | 作者提供LIP20、ATR18、Pascal7；原extractor用ResNet101，LIP473×473、ATR512×512 | LIP/ATR有Face、左右Arm；**无独立Neck/Ear/Hand**。不能从Face或Arm名字保证颈、耳、手都覆盖 | 官方simple extractor可把整图仿射缩放后输入，**不必脸crop**；但这些公开checkpoint是单人数据训练。多人扩展另接Detectron2，不能把simple extractor当已验证全图多人实例模型 | `.pth`可从作者README取得；官方主仓未提供现成ONNX。较重的ResNet101，不宜先承诺每帧低成本 |
| CIHP-PGN | 作者发布CIHP TensorFlow checkpoint；ResNet101/DeepLab-v2系主干，输出20类及边缘图 | 明确Face、Torso-skin、左右Arm/Leg；**无独立Neck/Ear/Hand**，Torso-skin不能自动解释为完整颈部 | **检测框无关的全图多人解析**。CIHP平均每图3.4人，训练域比单人肖像贴近多NPC；仍不是游戏小脸召回证明 | 官方TF1/推理脚本，非开箱ONNX/DML。原测试含六尺度×水平翻转；单尺度廉价版属于需重新验质量的改造 |
| BiSeNet-ResNet18，yakhyo发布 | 作者提供PT/ONNX及exporter；RGB NCHW512×512，19类；约11.2M参数/43MB | `skin=1`，`l_ear/r_ear=7/8`，`neck=14`。**ear_r=9是耳饰，neck_l=15是项链，不是耳/脖皮肤！** 无手臂/手类 | 接口可接任意图，但模型训练是CelebAMask-HQ人像；全场景缩512不等于可靠全图多人解析。实用时须给足脸+颈ROI，过紧face box会裁掉脖子 | 三者中ONNX准备最直接；固定512输入、动态batch、opset20。每个ROI一份成本，人数增加成本增加；AMD具体耗时未测 |

标签和输入直接来自[SCHP extractor](https://github.com/GoGoDuck912/Self-Correction-Human-Parsing/blob/master/simple_extractor.py)、[其全图仿射数据集](https://github.com/GoGoDuck912/Self-Correction-Human-Parsing/blob/master/datasets/simple_extractor_dataset.py)、[CIHP作者论文第3–4节](https://www.sysu-hcp.net/userfiles/files/2021/02/28/4ec79d892f719a29.pdf)、[BiSeNet标签生成代码](https://github.com/yakhyo/face-parsing/blob/main/utils/prepare_labels.py)与[ONNX预处理](https://github.com/yakhyo/face-parsing/blob/main/onnx_inference.py)。标签编号必须随checkpoint固定；CelebAMask-HQ原作者的另一套parser顺序不同，不能跨实现套编号。

## 预训练、许可及AMD接入

**SCHP：** [作者仓及下载入口](https://github.com/PeikeLi/Self-Correction-Human-Parsing)现重定向到GoGoDuck912，但LICENSE署名Peike Li。公开checkpoint为`exp-schp-201908261155-lip.pth`、`exp-schp-201908301523-atr.pth`等，**该官方列表没有CIHP checkpoint**。不要把第三方“SCHP-CIHP”模型卡冒作者现成权重。[代码MIT](https://github.com/GoGoDuck912/Self-Correction-Human-Parsing/blob/master/LICENSE)不等于已逐项核清下载权重和数据的再分发条款；本轮未找到独立权重许可说明。原网络的[InPlaceABNSync、AdaptiveAvgPool及align_corners插值](https://github.com/GoGoDuck912/Self-Correction-Human-Parsing/blob/master/networks/AugmentCE2P.py)需要导出审计：把训练用CUDA扩展替换/折叠为等价推理算子后，必须先对原PyTorch输出做数值验证。官方[多人扩展](https://github.com/GoGoDuck912/Self-Correction-Human-Parsing/blob/master/mhp_extension/README.md)依赖Detectron2，额外人体实例分割和ROI不能忽略。

**CIHP-PGN：** [官方README](https://github.com/Engineering-Course/CIHP_PGN)提供原checkpoint Google Drive入口，[代码MIT](https://github.com/Engineering-Course/CIHP_PGN/blob/master/LICENSE)；README未给独立权重再分发许可，本轮不猜其商用范围。它联合预测语义与实例边缘，完整实例划分工具是MATLAB；如果只需“所有人的皮肤并集”，可以研究只用语义分支，省去实例编号，但这是拟议集成而非已验证方案。[测试源码](https://github.com/Engineering-Course/CIHP_PGN/blob/master/test_pgn.py)确有六尺度和翻转，不能把论文质量对应成“一次512推理”的成本。静态单尺度导出可优先检查Conv/池化/Resize/Concat、NHWC↔NCHW及TF图转换；当前没有核到作者提供的ONNX或9070/DML时延。

**BiSeNet：** [作者发布页](https://github.com/yakhyo/face-parsing#download-weights-click-to-download)直接提供ResNet18/34的PT与ONNX，[exporter](https://github.com/yakhyo/face-parsing/blob/main/onnx_export.py)固定空间512、动态batch、opset20。官方示例推理选择CUDA/CPU，**不是已经使用DML**。主要Conv/BN/Resize等有希望转DML，但应审实际图的节点分配及CPU fallback；不要从“能加载ONNX”推导“全GPU”。[项目MIT](https://github.com/yakhyo/face-parsing/blob/main/LICENSE)，训练数据[原作者CelebAMask-HQ agreement](https://github.com/switchablenorms/CelebAMask-HQ#dataset-agreement)明确限制非商业研究及相关数据使用；代码、作者发布模型与训练数据的授权层次应分清，公开分发权重前需单独确认，不能只看MIT标识。该限制也适用于讨论其他CelebAMask-HQ face parser时的来源审计。

[DML官方ORT文档](https://onnxruntime.ai/docs/execution-providers/DirectML-ExecutionProvider.html)当前列到opset20，但明确存在不支持算子；固定shape有优化价值，需禁用memory pattern、使用ORT_SEQUENTIAL，同一session不能并发Run。DML1可用同一D3D12 device/queue；具体纹理预处理、buffer绑定及fence成本仍需实测。以上三者**均没有本次核到的9070 XT/真实游戏延迟证据**，不借CUDA、TensorRT或手机FPS报AMD成本。

## 为什么换检测器仍可能漏，以及可行组合

SCRFD→face parsing仍有第一道召回瓶颈：脸没检出，后级再准也不会运行。改高分辨率/多尺度检测会增加成本，脸crop放大也不能恢复原本不存在的细节。人体框+肩/耳/鼻关键点能帮助定位头颈ROI，降低仅依赖face box的风险；**关键点不是皮肤分割**，肩中点几何补“脖子”也不能冒语义标签。全图human parser不依赖face detection，却会因整图缩小损失小脸细节：例如1440高画面内24px高的脸缩到512高只剩约8.5px（几何示意，不是模型测量）。

针对脸脖色差，优先把可用脸、颈、耳及身体皮肤后验合成**同一保护alpha**，统一阈值、羽化和时间更新；不要脸保护1、脖保护0。BiSeNet应使用能看到完整颈部的ROI，人体解析补臂/躯干，空间重叠与缺失处需明确合并规则。只能补几何时要标成heuristic，不能算模型已覆盖。若业务能接受衣服也保留首遍，整人mask更容易保持头颈连续；这是保护范围的产品选择，由另一条整人模型调研评估。

## 小而有区分力的下一步

先做离线真游戏样本比较，勿直接替换当前实现：正常距离小脸、侧脸/背脸、多人、裸肩颈、手臂、遮挡、强光/HDR、运动模糊各挑样本；记录原图脸高度，分别量脸/颈/耳/臂漏保护率与背景误保护率。把检测召回、parser边界和最终合成色差分开。随后才对固定DML图测整条预处理→推理→alpha合成耗时及CPU fallback，不能只计NN。

整体产品先考虑整人mask，优先解决脸脖同一保护强度；精细皮肤解析作为第二阶段。在本解析支线内的对照次序：**BiSeNet-R18验证“脸+颈+耳”同alpha是否解决接缝；CIHP-PGN作为无需脸crop的全图/多人语义上限对照；SCHP-LIP/ATR作为可得PyTorch身体解析基线。** 这不是承诺它们已适用于游戏。三者训练均来自真实人物摄影，游戏脸、铠甲、发型、怪物和镜头特效属于未验证域；多人物训练也不自动等于小脸泛化。

另外，SegFormer是架构而非标签合同。[NVIDIA官方权重](https://github.com/NVlabs/SegFormer)面向ADE20K/Cityscapes，不能直接当“颈/耳/裸臂”模型，官方许可也写非商业研究/评估。所谓SegFormer human/face parsing必须再核其具体checkpoint、训练标签和权重授权；本轮不把未核的第三方权重列成第四候选。
