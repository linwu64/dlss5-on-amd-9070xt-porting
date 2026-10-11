# ACO机制与我方HIP可移植性

2026-10-11，只读调研；未安装、编译、跑GPU或改游戏。当前上游锁为[DLSSNR-AMD a9b13dd4](https://github.com/mochizuki0323/DLSSNR-AMD/tree/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67)，对应`v0.0.4-win-preview`。**Windows ACO Mode确实存在，不是只能在Linux运行；但它是离线ACO机器码经PAL/Vulkan ABI适配装载，加另一套优化shader/计划，并非给HIP换一个编译参数。**

## 已证机制

Mesa ACO名称是AMD compiler：NIR输入→AMD GCN/RDNA ISA的编译后端。标准RADV链是SPIR-V→`spirv_to_nir`→NIR优化/lowering→ACO→GPU ISA；提交命令、配置GPU寄存器、内存与队列则由Vulkan驱动负责。不能把编译器和整个驱动/提交系统当同一件事。[Mesa官方RADV编译流程](https://docs.mesa3d.org/drivers/radv.html#shader-compilation)

只读本地官方Mesa源`31e9a6b2e95e30d84bf3177d1f497d063e59b6b2`的`src/amd/compiler/README.md`和`aco_interface.cpp`，能确认divergence分析/指令选择、标量与向量寄存器分类、调度、寄存器分配、post-RA优化、ILP/VOPD、waitcnt/delay等阶段。这些可能改变VALU地址计算、活跃范围、spill、访存等待与指令重叠，但“VGPR更少”“编译更快”不等于本网络必然更快。本地Mesa版本只证明编译器机制，不是上游.nrps实际编译版本或本轮ISA计数证据。[官方ACO说明](https://gitlab.freedesktop.org/mesa/mesa/-/blob/main/src/amd/compiler/README.md) · [编译流程源码](https://gitlab.freedesktop.org/mesa/mesa/-/blob/31e9a6b2e95e30d84bf3177d1f497d063e59b6b2/src/amd/compiler/aco_interface.cpp)

### Windows不是标准RADV开关

最新[`nr_pipeline_binary.hpp`](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/windows/src/core/nr_pipeline_binary.hpp)的`create`/`import_pipeline`约186–255行实际执行：

1. 用AMD Windows Vulkan驱动编一个接口兼容的模板pipeline，以`VK_KHR_pipeline_binary`捕获其PAL容器。
2. 读取包内按SPIR-V hash索引的`NRPAL001`记录，取得预编译ACO ISA与资源/参数映射信息。
3. 调`pal::splice`替换ELF `.text`、插入参数适配stub并更新metadata，再导入pipeline binary创建compute pipeline；随后缓存转换后的binary。

[`nr_pal_binary.hpp`](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/windows/src/core/nr_pal_binary.hpp)约109–139、229–300行明确约束gfx1201/Wave32、PAL metadata3.6、单compute入口、资源与push范围、scratch限制，适配user SGPR/descriptor/push参数，并写回VGPR、LDS、float mode等。它不只是原封不动地复用驱动cache，也没有产生可直接交给HIP的.hsaco。Vulkan扩展提供binary捕获/导入接口，不保证任意编辑后的厂商私有容器跨驱动兼容。[Khronos扩展](https://docs.vulkan.org/refpages/latest/refpages/source/VK_KHR_pipeline_binary.html)

设备门要求AMD proprietary Vulkan driver、pipeline_binary/maintenance5扩展和feature，cache身份含设备/driver/UUID；作者仅声明RX9070XT、AMD Software26.9.2测试范围。具体fallback与开关覆盖见同目录上游审计，不把“请求ACO”当“实际跑ACO”。[官方README](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/README.md)

## 不全是编译器替换

最新[`nr_graph.cpp`](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/windows/src/core/nr_graph.cpp)可直接看到ACO开关联动：约181行chain kinds默认`0x1→0x1ff`；1168行改选ACO bundle的Linux shaders；3098–3105行改变projection选择；3221–3225行处理attention N-pair权重；4222–4226行改变upsample完整未shift网格条件。因此默认Off/On表包含shader、融合/链化、供数和计划差异，不能将全部变化记为ACO调度器贡献。`NR_ACO_NATIVE_KERNELS`可辅助逐核诊断，但权重布局/接口仍须核，不自动构成纯编译器A/B。

| 与我方差距的映射 | 可借鉴/可能贡献 | 本轮不能宣称 |
|---|---|---|
| uniform/divergent控制流、地址计算、循环phi | 在HIP中明确wave-uniform量、减少重复VALU地址运算和不必要活跃范围；比较实际ISA与资源 | 仅凭ACO名称或VGPR数断定occupancy、节省几毫秒 |
| cooperative matrix供数、packed FP8与LDS | 比较矩阵lane布局、global transpose load、成组load/store、K/V复用和对齐；我方LLVM23已有相关指令支持路径 | 同为WMMA就供数成本相同；一次SPV能代表Windows LLPC/ACO两份ISA |
| shader融合/链化、query tiling/权重排布 | 可把等数学的组织改写移到HIP，并锁原始packed bytes/还原置换及实际工作量 | 所有提速都是compiler；改tile后无需数值检查 |
| 精度、舍入、reduction次序 | FP8位置、half边界、FMA收缩、denormal/float mode和固定reduce顺序必须逐项锁 | 原网络精度下限声明等于与当前FAST1逐值相同；把int4 mixed的速度算到ACO |
| Vulkan队列/命令缓冲与互操作 | 同设备/命令buffer组织可影响APP与CPU喂队列开销 | ACO自身减少提交；APP互操作收益可以直接从pureNN差额扣除 |

我方生产模块混用LLVM/COMGR21与LLVM23配方，须按模块SHA/实际Fn/宏判断，而非全网一个LLVM版本。旧同条件1088/640数据约HIP8.93ms、mochi7.89ms，真实Windows cache是PAL/LLPC83.0；本地旧4f62 ACO surrogate不是那次测速版本。最新作者Windows7.21→ACO5.70ms也不是对我方当前HIP的同批比较。详见[性能证据边界](performance-evidence.md)与旧`mochi-driver-cache-20261006`记录。

## 能否接我们HIP

**不能把这些ACO records/PAL ELF直接作为HIP module load。** HSA kernel descriptor、kernarg、隐式系统SGPR、地址空间、scratch/浮点控制等与Vulkan PAL user-data ABI不同，都是GPU ISA不意味着二进制可互换。[LLVM AMDGPU ABI文档](https://llvm.org/docs/AMDGPUUsage.html)

可以研究的工程路线有两类：一是维持HIP，移植实际有效的等数学融合、供数和编译组织，必要时对少数热点做受控LLVM/ISA改进；二是新增独立Vulkan执行后端，研究类似的ACO→PAL适配、设备feature/cache身份、资源与同步合同。后者在Windows已有上游实例，所以不能简单说“做不了”；但也不是HIP编译器小替换。要包装ACO成HSA code object属于另一个ABI/运行时项目，本轮没有实现或兼容性证据。我们此前D3D12全网原型的全局UAV桥接成本同样不能拿来推断这个直接ISA路径的速度。

## 最多三条有区分力的后续验证（本轮未执行）

1. **先复现同a9的真实Off/On**：锁driver/GPU、有效/处理几何、token、完整块、seed/noise/history/预处理、实际计划及fallback日志，分开cold与warm GPU/wall，并保存同输入raw；不拿作者数字与旧HIP跨批相减。
2. **隔离一个热点的编译与供数**：共享输入/packed weights/矩阵形状/reduction，在可支持的条件下固定同SPIR-V再比较LLPC与ACO；否则明确记录shell/布局变化，先数值对账，再看实际ISA的VMEM/LDS/VALU、等待、VGPR/spill。不能只数静态指令就换算全帧份额。
3. **再选移植路线**：只有确认是某个融合/供数组织有效才移HIP热点；若收益来自直接ACO ISA与PAL路径，则评估独立Vulkan最小子图的ABI、同步、raw重复与稳定性。两者都不预承诺全网提速比例。
