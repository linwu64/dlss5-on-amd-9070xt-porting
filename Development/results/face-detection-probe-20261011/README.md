# YuNet实际CPU人脸检测：旧剑星菜单单帧proof

`annotated.png`来自实际OpenCV FaceDetectorYN推理，不是人工指定框。原1296×720图上检出1脸，置信度0.9267619，框xywh约[804.72,76.71,109.84,138.19]，五点为双眼、鼻尖、两嘴角；完整浮点坐标和原始15维检测行见detections.json。原尺寸成功即停止，没有640补跑或阈值追调。

输入是旧冻结HDR菜单的MODE0解码RGBA16F，**不是当前游戏截图**。保持此前统一曝光3.997892599→逐通道Reinhard→sRGB→uint8RGB，再按OpenCV接口转BGR。未缩放/补边，因此检测坐标与原图1:1；图的绿框和黄点均直接使用模型输出。

- 官方模型：OpenCV Zoo [YuNet目录](https://github.com/opencv/opencv_zoo/tree/47534e27c9851bb1128ccc0102f1145e27f23f98/models/face_detection_yunet)，锁commit47534e27c9851bb1128ccc0102f1145e27f23f98。使用face_detection_yunet_2023mar.onnx，232589B，SHA256 `8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4`，下载URL及support文件SHA见provenance.json。目录为MIT许可，原文保存在YuNet-LICENSE；模型raw不入git。
- 依赖：系统python无cv2，仅在外部隔离venv安装opencv-python-headless4.11.0.86，沿用已有numpy1.26.4，系统环境未改。
- 实测：Linux aarch64 CPU、OpenCV单线程、DNN_BACKEND_OPENCV/DNN_TARGET_CPU。**单次冷检测41.74ms**；模型创建/加载3.98ms；包含raw读取、固定显示转换、BGR准备及首次模型推理的CPU端到端约91.22ms。绘框和PNG/JSON写盘不在该e2e定义内。没有warm延迟测试，不能换算成游戏FPS、Windows9070XT性能或实时保证。
- 限制：一张旧菜单、正面角色脸。真人训练模型对游戏小脸、侧脸、遮挡/多人物未验证；置信度不是游戏准确率。这里只输出脸框+五点，不是逐像素皮肤/人物分割，也没有接入游戏或替换肤色遮罩。

复现使用外部模型与raw路径，在repo根运行：

```bash
/home/lmxxf/work/face-detection-probe-20261011/venv/bin/python Development/HIP/experiments/face-detection-probe-20261011/probe.py --model /home/lmxxf/work/face-detection-probe-20261011/face_detection_yunet_2023mar.onnx --raw /home/lmxxf/work/mode3-objective-20261011/old-menu/pair-decoded-before.rgba16f --out Development/results/face-detection-probe-20261011
```

模型固定下载地址：`https://media.githubusercontent.com/media/opencv/opencv_zoo/47534e27c9851bb1128ccc0102f1145e27f23f98/models/face_detection_yunet/face_detection_yunet_2023mar.onnx`。本次没有GPU推理、游戏启动/注入、配置/DLL更改或推送。
