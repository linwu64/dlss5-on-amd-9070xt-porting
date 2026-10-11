# 人物保护模型调研结论

优先做**全画面人物mask**，不要再把“先检出脸”设为保护前提。正常距离脸太小时，身体上下文能提供另一条定位路径；同一个人物mask也能让脸、耳、脖、手臂使用统一保护权重。首筛顺序是 **RTMDet-Ins-tiny作为多人全身效果基线，PP-HumanSegV2通用human作为低成本对照**，不是已经选出赢家。whole-person保护会同时让衣服/装备少增强，这是明确取舍。[整人详报](full-person.md)

| 候选/阶段 | 先验证什么 | 当前边界 |
|---|---|---|
| [RTMDet-Ins-tiny](https://github.com/open-mmlab/mmdetection/tree/main/configs/rtmdet#instance-segmentation) | COCO person实例mask并集，多人/遮挡/正常距离小人物；官方有ORT导出路径 | 640输入和后处理有成本；公开TensorRT/RTX3090时间不是AMD测量，DML算子/插件兼容未实测 |
| [PP-HumanSegV2通用human](https://github.com/PaddlePaddle/PaddleSeg/blob/release/2.10/contrib/PP-HumanSeg/README.md#42-general-human-segmentation-models) | 轻量语义人物前景，和上项同片段比较漏保护与成本 | 通用Lite/Mobile推荐192×192，小远人/头颈细节有明显分辨率风险；不要拿portrait权重与通用human混用 |
| 人体/面部解析：第二阶段 | 若还要保留衣服增强，再细分皮肤区域 | 已查模型标签各有缺口；不能把Face/Arm/Torso-skin自动当完整Neck/Ear/Hand。[标签与部署详报](skin-and-parsing.md) |
| RVM/SAM视频：参考阶段 | 看时序稳定、重捕获和难例上限 | 不先集成；RVM要GPU驻留循环状态，SAM要对象prompt/记忆系统，均无本机游戏低耗实证。[时序与接入详报](temporal-and-integration.md) |

下一步仅需小型真实游戏离线集：正常距离、转头、多人交叉、遮挡重现、快速镜头/切镜，按脸和人体大小分桶，比较脸颈漏保护、连续漏帧、边界跳变、保护一致性及完整GPU/wall成本。没有模型已证明能在本游戏稳定识别小人，也没有已验证的AMD低毫秒承诺。低频检测后逐帧传播必须有正确MV/depth/帧序合同；没有就不能伪称运动补偿。本轮没有下载大模型、跑GPU或改游戏，保持当前MODE0配置；后续保护应保留普通NR base、只压制新增增强，而非把人物替回原图。
