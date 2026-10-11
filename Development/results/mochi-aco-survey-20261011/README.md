# Mochizuki ACO模式调研结论

最新`a9b13dd4`/`v0.0.4-win-preview`的Windows ACO模式是真实存在的：用驱动生成PAL模板，再替入离线Mesa ACO ISA、适配参数和metadata，通过Vulkan pipeline binary接口装载。它不是“Windows不能用ACO”，也不是给HIP加一个ACO编译flag。[上游及机制](mechanism-and-portability.md)

作者1080p离线network表为Windows7.21→ACO5.70ms，耗时约降20.9%；4K为27.32→22.49ms，约降17.7%，scope是RX9070XT/26.9.2。但ACO开关同时选择Linux优化shader、链化/融合、权重供数及部分网格计划，默认Off行和On行的版本/条件也需锁，不能把全部差值归因编译器，更不能直接当成我方HIP收益。[性能证据](performance-evidence.md) · [最新上游与资格审计](upstream.md)

对我们最实际的顺序是先做同版Off/On锁账，再用一个热点拆清compiler与供数/融合贡献，最后决定移植等数学HIP优化还是新增独立Vulkan路径。PAL与HSA ABI不兼容，现成records不能直接当.hsaco；Windows二进制适配可研究，但需driver、数值与稳定性验证。本轮未安装、编译、跑GPU或改游戏，未承诺快多少。
