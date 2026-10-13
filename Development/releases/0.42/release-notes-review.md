# 0.42 发布说明独立核对建议

基线31f5c239；只读核当前双语CHANGELOG、DevHistory已采纳摘要、WorkingPlan、配置模板及正式结果索引。下文是给打包主控的短稿，非对外发布动作。0.41正式包/tag不回写，0.41-a不列正式版本。适用AGENTS中无另外的发布审批规则；保留无Co-Authored-By、不推送/不动玩家配置。

## 建议正式摘要

0.42整合0.41后的数据流优化、可选历史/单遍增强，以及紧凑权重和无历史会话资源优化。新安装默认仍1x、MODE0、肤色保护关闭；PRED1只在选择3x时使用两遍网络+预测第三遍，MP1不因此多跑网络。不会覆盖已有custom/native文件；旧配置与系统环境可能盖过包默认。

- **已采纳数据流/计算优化**：最终RGB直接写共享输出，省最后一次device copy；block4 pool→首C64传递已量化FP8字节；原生1440的FAST3 C256 persistent路径。C32 norm900逆平方根复用仅1600×960/FAST1/单遍等已验范围，1152保持原路；Auto提交只在已验证驱动/runtime/profile使用一个已有自有timed事件，否则回落。不同实验改善不相加，不换算整包FPS。当前CHANGELOG从0.41到10-06只列H900，前三项数据流优化应在0.42摘要补上。
- **可选时序/增强**：统一`DLSS5_TEMPORAL_MODE=0/1/2/3`，默认0；1为TheAutomatic Fast History（PR12近似实现+输入反馈），2只平滑修正的低频，高频用当前帧，3单NN后加强低/高频修正。MODE3强度默认1、范围0..2，只作用3，0保持原NN输出；不等同第二遍NN，不保证细节/画质改善。PR12辅助输出/codec接口保默认旧行为。
- **范围及默认**：主动模式需MP1、HIP、无graph/overlap/外部history，改变模式/增强强度需重启，F9在1/2/3下阻止写入MP2/3。新MODE含0优先旧FAST_HISTORY；reference诊断不能叠加。未声明可信无抖动MV/深度方向时明确static fallback，可能拖影；RE9 runtime走该静态路径。模式1须随包提供64B post70-history-head.f16及匹配C32aux exports；模式2/3无新增NN权重。当前文档未承诺Magpie新时序consumer，Magpie保持MODE0，不把通用配置键存在当其模式已验。
- **资源**：8个expand已省96MiB；contract/projection原packed bytes+4096B scale尾相邻存储再省96+24MiB。已验9070XT/1152 profile权重累计216MiB容量减少，**相对已经expand的基线后两项是120MiB，不能再算一次旧96**。未知布局、legacy cache、缺newexports成对旧buffer/旧kernel回退；contract/proj内部默认只已验gfx1201/profile，gfx1200保旧路。显式NeverHistory MODE0会话少33.75MiB共享history buffer，公共unknown和history保旧。分配宽度不是residentpeak，driverfree另列；没有稳定FPS承诺。
- **兼容修复**：首用RGB UAV→SRV状态恢复、MinGW宽路径、FastHistory资源/提交退休及MP guard、F9先检查后写配置。普通HIP addon与独立runtime均包含mode1配套支持；保原runtimeABI。

## 文案需避免的边界

1. 0.41的fast-vit/C512 directpack/3x预测/1440整块融合本身已是旧功能，不再当0.42新成果；上面新1440 persistent是另一条后续已采纳路径。
2. 已实现的MODE3曾在旧真实菜单sameNN/samedecoder观察到局部反差/颜色变化，用户未保留；不写“新增细节/普遍抑闪/一次等两次/免费画质”。新包默认0，不沿用本机试装MODE1/3个人配置。
3. 最近V末barrier、prefix main NT、C32 NoHi、C512少New、tile-ready、graph替换均STOP，不列功能；nativeD3D12是慢的隔离研究，不给用户新增backend选择。人物分割/YuNet仅调研/demo，未集成。
4. gfx1200编译/ELF/导出核不等硬件验收。0.42模块数以最终manifest为准，不沿用0.41的38/arch或本机79数量。
5. 历史记录中的“未发布/未部署/仅源码”保留原日期意义；新增0.42总段说明本次已包含哪些成果，不能让0.42包内说明仍只写0.41。模板要写0..3（现部分英文注释仍只列0..2），默认MODE0/MP1/SKIN0/PRED1三包一致。

## 独立包核约定

三ZIP最终输出后记录完整SHA256/字节/entry数，回读每entry并核CRC/载荷SHA；共同模型、模块、shader/row与正式构建manifest一致，三包中共同addon/runtime按对应路线核身份。检查default-config/template默认值、不塞玩家custom/native、许可/source归属及RE9配套host/runtime路径，排除调试raw、私有NR实验开关和临时0.41-a说明作为默认入口。结果写同目录独立receipt；本审不运行包中程序、不GPU、不对外上传。

LLVM23前置12行独立小核已另存`llvm23-independent.json`：source/binary SHA、2arch×6row ELF target、8个C32包的mode1两aux出口104B ABI通过；新FAST为ff5b04…，不是旧f46。静态结果不充当正式新载荷游戏/性能验收。
