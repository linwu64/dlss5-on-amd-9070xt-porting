# 整个人物保护：先筛两条真正不同的路线

调研日期2026-10-11；只读官方论文/代码/模型说明，没有安装框架、下载大权重、推理或改游戏。目标不是再找一个脸框：第一遍全画面正常NR，后续遍对**同一个完整人物区域**统一减弱新增增强，避免脸与脖子变成两个处理区。建议首筛 **PP-HumanSegV2通用human** 与 **RTMDet-Ins-tiny**；不是声称它们已经解决游戏里的远人、侧面或遮挡。

设第一遍结果为Y1，多遍结果为Yk，全人软mask为M∈[0,1]，可比较 `Y=Y1+(1-βM)(Yk-Y1)`。β=1时人物保留第一遍；β<1只减弱。必须在相同工作域混合。这里M覆盖衣服/装备而不只是皮肤，代价是**人物服装也少增强**；它能统一脸脖风格，但不能等同“保留所有衣服增强、只保护裸露皮肤”。这是产品取舍，不是换模型就自动两全。

## 1. PP-HumanSegV2：选通用human权重，不选会议portrait权重

输入普通照片RGB，经配置的Resize/Normalize，输出前景/背景两类：softmax版本为2通道置信图，argmax版本为1通道标签。**通用Lite/Mobile推荐输入均192×192**；portrait Lite的256×144、96.63%mIoU与5.4MB不是同一通用模型，不可搬来做预算。通用模型在广泛human数据训练，再用小型Supervisely Person测试；Lite mIoU92.52，Mobile93.13。官方为Lite给出骁龙855单线程/PaddleLite约15.3ms；Mobile表列Nvidia GPU2.67ms，但同页未明确该GPU型号/该列部署环境，不能当9070XT延迟承诺。来源：[官方PP-HumanSeg说明和通用表](https://github.com/PaddlePaddle/PaddleSeg/blob/release/2.10/contrib/PP-HumanSeg/README.md#42-general-human-segmentation-models)。

它不需要先检测脸，二值语义图天然可表示多个人的并集；官方提供通用全身示例，但**没有给出游戏、多人物拥挤、小远人或遮挡分项召回**。因此“可产生多人的mask”和“每个小人都不会漏”必须分开。输入低分辨率是实质限制：若画面高1440像素、人物高60像素，直接缩到192高仅约8像素；头、颈、手更少，不能靠后续上采样补回证据。这是分辨率推算，不是该模型实测漏检率。

真实可下载资产（官方链接，本轮未下载/解包）：

- [通用V2-Lite softmax部署包](https://paddleseg.bj.bcebos.com/dygraph/pp_humanseg_v2/human_pp_humansegv2_lite_192x192_inference_model_with_softmax.zip)
- [通用V2-Mobile softmax部署包](https://paddleseg.bj.bcebos.com/dygraph/pp_humanseg_v2/human_pp_humansegv2_mobile_192x192_inference_model_with_softmax.zip)
- [Mobile配置](https://github.com/PaddlePaddle/PaddleSeg/blob/release/2.10/contrib/PP-HumanSeg/configs/human_pp_humansegv2_mobile.yml)：PP-LiteSeg/STDC路径，2类；部署包实际文件体积本轮未核，不能借portrait的5.4MB代填。

AMD路线是导出Paddle inference→[官方Paddle2ONNX](https://github.com/PaddlePaddle/Paddle2ONNX)→固定输入ORT CPU对齐→ORT DirectML试完整图。旧2.x部署资产与最新3.x转换器格式不同，需锁兼容版本；不建议现在重写到自家HLSL。Conv/归一化/激活/Resize等算子组合看起来适合常规推理，但**未实际导出、未核DML分区，不叫AMD已经可用**。代码项目[Apache-2.0](https://github.com/PaddlePaddle/PaddleSeg/blob/release/2.10/LICENSE)已核；权重由同项目官方发布且说明可直接部署，未见另列权重条款，本轮未解包核附带NOTICE，分开记录而非自动称所有二进制已审。

## 2. RTMDet-Ins-tiny：全图多实例person mask，输入成本更高

COCO预训练的80类实例分割，输入通常640×640（保持配置的缩放、padding、归一化），输出多个box、类别/分数及各自mask；筛person并做并集，不必先看清小脸。它是可见实例分割，不重建被遮挡的人体部分。官方tiny为5.6M参数/11.8GFLOPs、COCO整体mask AP35.4；**不是person专属、小目标或游戏指标**。其1.70ms是RTX3090/TensorRT8.4.3/cuDNN8.2/FP16/batch1，保留top100 masks且包含后处理，不是AMD/DirectML数字。来源：[官方模型表与测试条件](https://github.com/open-mmlab/mmdetection/tree/main/configs/rtmdet#instance-segmentation)、[COCO训练与模型元数据](https://github.com/open-mmlab/mmdetection/blob/main/configs/rtmdet/metafile.yml)。

这条对“多个NPC、全身区域”的任务定义比自拍抠图更贴合，但仍会受640下的小人体、遮挡、低对比、游戏材质域影响；检测分数/NMS也可能先丢掉小人。不能从COCO总体AP推出远处游戏人物保证。5.6M是参数量，不是实测文件MB；裸FP32参数量级约22.4MB，实际checkpoint/导出图大小未下载核。

- [官方tiny预训练权重](https://download.openmmlab.com/mmdetection/v3.0/rtmdet/rtmdet-ins_tiny_8xb32-300e_coco/rtmdet-ins_tiny_8xb32-300e_coco_20221130_151727-ec670f7e.pth)
- [模型配置](https://github.com/open-mmlab/mmdetection/blob/main/configs/rtmdet/rtmdet-ins_tiny_8xb32-300e_coco.py)
- [官方RTMDet-Ins ONNXRuntime部署说明](https://github.com/open-mmlab/mmdetection/tree/main/configs/rtmdet#deploy-rtmdet-instance-segmentation-model)明确支持，不应因MMDeploy总表只列RTMDet检测就误判不支持实例分割；[640静态ORT配置](https://github.com/open-mmlab/mmdeploy/blob/main/configs/mmdet/instance-seg/instance-seg_rtmdet-ins_onnxruntime_static-640x640.py)真实存在。

AMD路径先MMDeploy导出静态640 ONNX，核NMS、动态mask生成/索引/Resize及任何custom domain，再试DML。官方的ORT支持**不等于DirectML全图支持**，更不等于无需CPU后处理/拷贝；可把后处理单列D3D12 compute，但尚未实施。代码[MMDetection Apache-2.0](https://github.com/open-mmlab/mmdetection/blob/main/LICENSE)已核；该权重是官方model zoo发布，本轮没找到该.pth独立许可声明/未检查包内notice，不用第三方HF移植的license代替原资产证据。

## 为什么此轮不把自拍抠图当答案

MediaPipe Selfie、MODNet等肖像模型训练目标与正常游玩远处全身人物不同；RVM的全身/时序能力和状态成本由另一份时序调研负责。它们可以成为近景人物对照，但这次先不扩大候选，也不拿webcam演示覆盖游戏要求。由官方模型卡明确写出的限制，比“实时人像分割”这个名字更有判断价值。

## AMD落地与选择边界

[ORT DirectML官方文档](https://onnxruntime.ai/docs/execution-providers/DirectML-ExecutionProvider.html)支持DX12 AMD设备，并列opset/算子限制；它不是任意ONNX都落GPU的保证。两个候选都需要实际图分区、首尾数值及端到端拷贝/同步成本核对。本轮没有AMD延迟、游戏mask精度或抑闪结果。

如果下一步做少量离线首筛，应同时覆盖近景/正常游玩小人/多人遮挡/脸脖连接，记录漏保护和过保护，而不只再拿一张大正脸。全人方案若能稳定包住头颈和身体，可先作为**一致减弱整个人的保守baseline**；若必须让衣料仍吃满后续增强，则需要另一条人体解析/皮肤标签路线，不能把wholeperson当它的同义词。所有候选当前都只是候选，未部署、未改默认、未预设已解决。

## 来源与查询范围

上述链接均是模型作者/维护方的官方代码、发布资产或框架官方文档；未用论坛二手速度数字。源码以PaddleSeg release/2.10、MMDetection/MMDeploy main查询，版本分支可能移动，真正下载/导出时再锁SHA与asset hash。本轮只读取文档和代码/HEAD元数据请求，没有安装框架或下载这些权重。PP通用输入/指标/下载来自其README；RTMDet元数据/导出/许可分别核对，没有把检测模型速度、portrait指标、参数MB估算与实际权重文件大小混为一谈。
