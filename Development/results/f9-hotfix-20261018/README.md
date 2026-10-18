# 0.44 F9 紧急修复（2026-10-18，验收进行中）

Zero实机暴露了上次验收缺失的两种实际宿主条件：延迟提交的pre-upscale producer，以及WindowsApps只读配置路径。本次针对这两种条件修复、建立回归并更新0.44。以下初次GPU结果因为门禁错误不作为正式交付验收，等待完全空闲后的`-idle-r2`重验。

- `native_game_oneshot.h`只在Process之前查询能否direct；Process之后再取得当前DirectOutput，避免返回已重建销毁的纹理。
- `NativeGameFrame`永久保存SuppressFps状态；工作/有效尺寸与时序相同的模型切换只更新geometry和network，不销毁D3D12输出。900等尺寸变化仍重建。
- Network分表保留Small/Original两套GPU权重与gain，不清空、不在热切时同步/读资产；Small完整性在创建时检查并缓存。同尺寸原模型SP计划的权重引用保持存活。
- 默认1080 Small启动时预热Small/Original，外部input wait前对每种冷模式完成scratch预热（AE与EXACT两种算子布局），严禁wait之后调用同步Upload，违例明确报错以代替死锁。
- F9立即更新原子模式和hot snapshot/generation。写盘是best effort，消费自身修改的时间戳，磁盘失败不会在下一帧或一秒轮询时撤销模式；后续外部编辑仍可覆盖。系统显式环境覆盖保持原规则。
- OnimushaWotS宿主优先选`C:\XboxGames\Onimusha- Way of the Sword\Content\DLSS5-AMD`，避免WindowsApps虚拟目录；即使目录仍拒写，内存切换也正常。

CPU只读测试已过：custom/native保持0.5，循环1/2/3/0.5/1，立即和1.1秒后模式均保持；随后外部编辑native到2会重新加载。回执见readonly.stdout/stderr。

## GPU门禁失误（必须保留）

第一次`run-gates.ps1`的Idle函数把game-check文字输出和返回bool一起留在PowerShell成功输出流；busy时返回非空数组，被if转为true。deferred-warm/cold/ae、direct-switch-1080/900因此在鬼武者后台PID27916仍运行时误执行，违反约定。没有修改安装目录，作业结束后锁已释放。后续Gold沿用原严格门禁，被正确拦下。

已把文字输出导向Out-Host，Idle仅返回退出码判断后的布尔值；在实际busy状态确认输出WAIT_GAME_EXIT且没有gpu.lock。初次结果保留排错，不作为正式空闲验收。已明确告知Zero/鳩，等待真正退出后重跑全部门，后缀`-idle-r2`。
