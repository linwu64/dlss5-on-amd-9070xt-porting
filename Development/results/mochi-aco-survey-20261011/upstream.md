# mochizuki Windows ACO Mode：上游版本与实现范围核实

2026-10-11，只读官方GitHub/API和少量锁版本源码；未下载发布包/模型/`.nrp`二进制，未安装、编译、跑GPU或修改游戏。先说结论：**确有新的Windows ACO模式；不是在Windows安装RADV，也不是只把原Windows shader换个编译器。** 它带Linux网络的SPIR-V与预编译ACO代码，借AMD Windows驱动的PAL容器和pipeline-binary接口加载；网络组织/同步选择也随模式改变。

## 找对仓库、锁定版本

本项目旧记录`mochizuki-022-20260928/upstream-sources.json`和`mochi-old-lock-20261006/README.md`均指向[mochizuki0323/DLSSNR-AMD](https://github.com/mochizuki0323/DLSSNR-AMD)，描述也是DLSS5 NR/RDNA4/Vulkan，非同名项目。官方API在本轮返回唯一分支`main`。

| 身份 | 锁定值 |
|---|---|
| 最新main/Windows preview tag | `a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67`，`v0.0.4-win-preview` |
| 提交时间 | 2026-10-10T18:05:57Z（北京时间10月11日02:05:57） |
| 发布 | [v0.0.4-win-preview](https://github.com/mochizuki0323/DLSSNR-AMD/releases/tag/v0.0.4-win-preview)，2026-10-10T18:16:32Z |
| 直接父版本 | `9e4574e1812d7d0632d6db02721a20c9617be434`，Linux`v0.0.4` |
| 我们旧实际测速 | `d1185d25141b1714d7837151b6fa782e6427568b`，`v0.0.2.5`；不是新的ACO实现 |
| 本地历史ACO surrogate | `4f62a8a6900a4cbf70563ea3df2c5e3348ff63a6`，旧Linux源码代理；不能冒旧Windows测速ISA，更不能冒本次新模式 |

版本依据：[锁SHA提交](https://github.com/mochizuki0323/DLSSNR-AMD/commit/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67)、[官方branches API](https://api.github.com/repos/mochizuki0323/DLSSNR-AMD/branches)、[tags API](https://api.github.com/repos/mochizuki0323/DLSSNR-AMD/tags)、[release API](https://api.github.com/repos/mochizuki0323/DLSSNR-AMD/releases/tags/v0.0.4-win-preview)。API是本次查询时的快照，后续以锁SHA为准。

## 用户开关、平台与资格回退

游戏目录`dlssnr-amd.ini`的`[Network]`下`ACO Mode = 1`启用，`0`是默认，重启游戏才生效。[配置解析](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/windows/src/pe/nr_pe_config.cpp#L374)使用一次性初始化，接受aco/aco mode/acomode；[安装INI生成器](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/windows/package/make_ini.py)明确生成默认0。`NR_ACO_DIR/CACHE/SHELL_DIR/NATIVE_KERNELS`是源码中的诊断控制，不能当普通安装步骤或与默认配置混用。

这是Windows x86_64实验发布包。项目支持目标为RX9000/RDNA4；作者仅验证RX9070XT/AMD Software26.9.2，其他卡和驱动不是已验证支持。Linux原版本来走Mesa/RADV/ACO，和Windows这个可选导入模式需区分。最低Windows具体build本轮未确定，不填猜测值。[锁版README平台说明](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/README.md#L266)。

[src/core/nr_pipeline_binary.hpp的Features::prepare](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/windows/src/core/nr_pipeline_binary.hpp#L65)实际要求AMD vendor和AMD专有Vulkan驱动、`VK_KHR_pipeline_binary`、`VK_KHR_maintenance5`及对应feature开启；不满足会将该进程的ACO模式禁用，按原驱动路径继续。已有host device未开启pipeline binaries也会disable。缺少bundle的records/shaders目录则配置阶段直接记录原因并留在原路径。

**不能把资格回退理解为任何错误都能安全自动回退：** `create_or_default`在Off/disabled或非网络shader时调用普通driver编译；在已启用的网络路径中，缺record、SPIR-V hash不符、不可导入等是require/check/异常路径，本函数没有逐kernel静默替回LLPC的兜底。本轮不宣已验证所有外层错误恢复分支。要判实际使用，应看`dlssnr-amd.log`的资格/禁用原因和实际pipeline状态，不只看INI值。

## 实际加载和覆盖范围

[架构说明](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/docs/ARCHITECTURE.md#L87)与新`nr_pipeline_binary.hpp`/`nr_pal_binary.hpp`对应：先用同接口template让AMD驱动创建并捕获PAL pipeline container，再放入ACO代码，最后经`VK_KHR_pipeline_binary`导入。不是HIP/HSA code object直接加载，也不是仅将原驱动pipeline cache拷入另一目录；ABI细节由另一份机制报告展开。

| 部分 | ACO On实际选择 |
|---|---|
| C32/64/128/256 fused Swin、C512 attention/FFN/projection、ViT GEMM/QKV/attention、网络head/up/down等`g_*.spv` | `network_path`按`g_`名称前缀识别；读取bundle Linux网络SPV，以其hash查对应`.nrp`记录。具体是否完整覆盖某一实际shape必须核record/实际pipeline，不能由目录名字保证 |
| `temporal_pre_fp32*`、`temporal_post_fp32*` | 也被识别为网络kernel，使用ACO bundle相应SPV/record |
| runtime encode/transfer/downscale/upscale/taps等路线适配pass | 源码明确两模式均由Windows驱动编译，不是整帧所有GPU工作都ACO |
| 已导入binary缓存 | `dlssnr-amd/aco-cache`，key绑定record/template、GPU/driver identity、push大小和workgroup；不是可任意跨驱动使用的ISA包 |

依据：[network_path/create_or_default](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/windows/src/core/nr_pipeline_binary.hpp#L139)、[runtime适配pass](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/windows/src/core/nr_runtime.cpp#L1290)、[temporal选择](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/windows/src/core/nr_runtime.cpp#L1535)。最新提交加入**58个`.nrp`文件**和7行shell alias；58不是dispatch数或58个网络算子。未下载/反汇编这些二进制，本轮不宣已独立重现其ACO生成版本和全部shape覆盖。

## 开关并非纯compiler控制实验

相对父版本的[实际commit diff](https://github.com/mochizuki0323/DLSSNR-AMD/commit/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67)包含Windows shader展开器、shader宏、tile-counter链、ViT尾块处理及宿主图等变化。即使在同一新版本内，ACO开关也触发这些选择：

- [nr_graph.cpp:1168](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/windows/src/core/nr_graph.cpp#L1168)改读`aco/shaders`，该目录由Linux build_network生成，不是同一份Windows SPV仅换编译器。
- [tile-chain选择:181](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/windows/src/core/nr_graph.cpp#L174)的默认kinds由Off `0x1`变为On `0x1ff`，涉及更多ViT/encoder/decoder的跨dispatch依赖；资格还受编译宏和数据条件控制，不能只报该mask当全链实际启用计数。
- [投影选择:3098](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/windows/src/core/nr_graph.cpp#L3098)与[attention权重:3221](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/windows/src/core/nr_graph.cpp#L3221)存在模式分支：kernel组织不同，ACO attention要求N-pair QKV权重并由host重排。源码注释的等价意图不是本轮数值验证。

同提交还新增`NR_EXP_NOHI`权重审计下的去上界clamp变体、扩展uint/continue/矩阵length的静态展开，以及ViT越界key由矩阵零值选择改成clamped load后标量归零；本轮未做任何跨模式raw误差测试。官方README本身也提到Windows driver路径与Linux路径有舍入差异。故“ACO快”不能自动转述成“数学逐位相同且收益全部来自编译器”。版本间同时改了native D3D↔独立Vulkan共享纹理/fence路线和OptiScaler版本，也不能把游戏FPS变化单归ACO。

## 构建与发布二进制来源

[windows/build/build_package.sh](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/windows/build/build_package.sh#L117)先构建Windows runtime/addon等，再调用`linux/build/build_network.py rdna4`生成ACO bundle SPV，**拷贝仓库已有`.nrp`**及alias；该打包脚本不重新调用ACO生成这些record。需要已有fetch_deps依赖、MinGW/Vulkan headers、Python等；这只是流程说明，本轮没有执行。完整Mesa提交/record重生配方未从这些打包文件核定，不宣“单跑打包脚本已从零复现ACO机器码”。

[官方GitHub Actions](https://github.com/mochizuki0323/DLSSNR-AMD/blob/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/.github/workflows/packages.yml)在Ubuntu24.04使用MinGW交叉构建Windows包，tag任务创建release；检查包内不携带用户模型。发布asset：`DLSSNR-AMD-Vulkan-Windows-0.0.4-win-preview-x86_64.zip`，170,619,111字节；GitHub release API发布的digest为`sha256:ce421e5d4481d7899cd1560dcd024f74227dff965a6f3e0517188190e127b69f`。此为官方元数据，**本轮未下载后重算SHA**。模型仍需用户自己的`nvngx_dlssnr.dll`310.8.0提取；不能把包内ACO记录当模型，也不能把此Vulkan二进制直接替换本项目HIP/D3D12实现。

## 旧比较的边界与后续证据

旧d1185实测Windows ELF来自LLPC83；当时Linux ACO代理仅用于看组织，不代表Windows实际ISA。新a9b13确实引入Windows ACO导入，不能用旧事实否定新实现。反之，新release也不能倒改历史测速身份。作者性能表的版本、原始协议与数值由性能报告单独核查；本文件不新增测速或归因结论。

只读源码副本位于`/home/lmxxf/work/dlss5-upstream-aco-survey/a9b13dd4cdb5f4bf43db358492d72e6e5e2acd67/`，与旧`aco-isa/mz`及9070旧对手资产完全分开。这里是少量HTTP源码，不是新安装或运行产物。
