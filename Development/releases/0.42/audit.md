# 0.42 独立载荷审计（2026-10-13，进行中）

审计范围：只读源码、正式构建来源、三包结构/默认配置/manifest；不编译、不使用 GPU、不发布、不修改产品。基线生产 `31f5c239`，独立树 `dlss5-release-042`。适用根/微信/297 AGENTS 已核，用户本轮授权三包放 AMD `D:\給網友打包`。

- 三种正式包沿用 0.41：Magpie、OptiScaler、OptiScaler-REFramework。0.41a 仅临时包，不能作为正式前版或 release 版本。
- 当前 `hip/build-modules.ps1` 实际 **40 行/架构**；旧 0.41 `elf-targets.json` 为38。新增恰为 `c32-wave1-fast-norm900`、`swin-persistent-fast`。活跃目录43和游戏79文件均不是正式白名单；不得直接复制残留目录。
- 对旧正式源码 `ab8e3e82`，HIP改变文件为 `c32_fused_ffn_attention.hip`、`wave_owned_c32.inc`、`deep_fast.hip`、`vit_stream.inc`、`multihead_fast_padded.hip` 与构建配方。引用改变源码的行不能只因名字一样复用。未变行可按完整 generated source SHA、编译器/选项/架构与 binary SHA 复用；已验正式新产物可绑定既有构建receipt。`-PrebuiltDir` 自身仅复制，不核源码SHA，不能单靠新 manifest 的 sources 字段证明来源。
- 新 tail 两入口由正式 `deep_fast.hip + vit_stream.inc` 配方进入 vit-stream/fast；gfx1201 已验 joint fast SHA `da1b4ae9af3c1d2889f86e530b915971494ff2a58156a6abab2813dfb2d26014`。loader 默认 compact 宏1，但真实 device/gfx1201/RX9070XT、固定profile/消费者与 HasFn 守门；gfx1200/缺入口/旧cache坚持旧buffer+旧kernel，不冒已验新路径。
- 模式1 C32辅助入口与64B `post70-history-head.f16`（SHA `77c745c4e1d84a6227a2224291d83c37d1e9bd18d45e95add166b1174225ce8f`）需与最终包资产核对；默认off不能代替可选功能所需资产。旧gfx1200未实机验证不得称双架构新功能已验。
- 当前三 HIP flags 均 TEMPORAL_MODE0、MULTI_PASS1、SKIN_PROTECT0；PREDICT1 是原公共默认，仅MP3执行，不能把剑星试用PRED0误作公共默认。不得打包个人 custom-config.txt/native-game-flags.txt；仅模板。
- 当前生产头无 NoHi、V-tail、main-NT、host-QPC 私有路由。阶段2 C512删除临时tensor已撤回；已采expand96MiB、NeverHistory及contract/projection tail保留。实验源可作为归档但不可成为运行载荷/默认开关。
- 旧 `scripts/release-check.sh` 指向旧D3D装载/游戏位置且会重编，不能作为本轮HIP正式准入。`scripts/package-release.py` 单独也不复制HIP/Runtime/row；主应沿正式三包补包流程核验。

最终 ZIP 的路径/逐文件SHA、三包版本文档、架构清单、row/Runtime/addon与构建receipt一致性：待主产物，不将本审计前置结果写为已通过。

## 正式 LLVM23 六行双架构构建

主协调授权审计员承担必要 CPU 构建；实际 session `73062` 权威 exit0，不使用设备。`llvm23/build.sh` 原样调用正式 `compile-modules.py`，MSVC辅助ABI、`-real-true16`、recipe rowopts，六行×gfx1200/gfx1201=12产物。`llvm23/manifest.json` 记录每行完整 source SHA/defines/commands/compiler/binary SHA，`receipt.json` 锁 source commit/clang SHA/终态。12项 source/binary SHA已读回复核，独立审另交 remaining。

本轮 fresh generated source 的 C32-fast SHA为 `ff5b04c666fed772c72b8a0d30bb49f1bb3eacb887f211403e181caed0c9a2a7`，不能冒旧模式试验 `f46b...` 二进制身份。完整新载荷须引用本轮manifest，不把旧f46证明机械移植为本轮所有导出运行证明。

独立审 `llvm23-independent.json` 已由 remaining 完成：12源码/ELF SHA实际重算、双架构 target正确；8个C32产物的 post_logit/post_b8_logit 为104B/align8/wave32/WG32，实验后缀无。本轮正式 gfx1200 C32也已fresh编入aux（上方旧模式资产receipt的gfx1201-only仅历史边界），但本轮没有双架构GPU新功能实测。尾compact仍仅gfx1201/RX9070XT获资格。

## 包装脚本及文案前置复核

`package-042.ps1` 已改为0.41正式ZIP为基线、40×2官方白名单、当前addon/runtimeSHA与64B row硬核；regular/Magpie不ship用户custom/native，REFramework保来源/许可及Runtime结构。双changelog0.42、README当前版与六类package notes保旧版本为历史，明确MODE0/1x/SKIN0、PRED仅3x、153.75MiB与先前96MiB边界，不承诺FPS；不纳STOP候选/hostQPC/独立D3D12研究后端。未见阻塞的scope/default问题。

已发主两个小修：脚本头旧0.41←0.40注释；合并LLVM manifest取不存在的`opts`会丢选项，应保完整`commands`（原LLVM receipt已保存真实rowopts）。最终ZIP仍待实际产物核。
