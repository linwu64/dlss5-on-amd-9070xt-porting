# 0.44 F9 紧急修复（2026-10-18，最终4764e4f1回归/部署/三包均完成）

Zero实机暴露了上次验收缺失的两种实际宿主条件：延迟提交的pre-upscale producer，以及WindowsApps只读配置路径。本次针对这两种条件修复、建立回归并更新0.44。初次GPU结果因为门禁错误不作为正式交付验收；完全空闲后的`-idle-r2`正式重验现已全部通过。

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

## 正式空闲验收（-idle-r2）

- 源码 **6794c379**，addon SHA **315eae41025f9e46b578a6a6996b1df0829107157bdebaaa5729618679ef4fdb**；runtime SHA **015d96115a30a709220bce3b2b812a4a90383b17d76cf3d36727972b5293b1b9**。最终产物逐SHA见accepted-host-builds.json。
- deferred-warm/cold/ae三组各跑0.5→1→2→3→0.5→1→0.5。CPU故意扣住GPU producer fence，只有Enqueue返回后才放行；每帧都在producer未完成时返回，8秒自救释放未触发，输出finite且同模型往返逐位一致。默认1080预热Small/Original后，第一下0.5→1与后续回环的同步Upload调用增量均0。第一次2x额外初始化两份feed（在wait之前）；不把回读/CPU比较在内的总wall_ms当成热键开销。
- AE测试也预热AE与EXACT两套算子布局；预热不消费F8键，也不改变用户的F8状态。两套模型GPU权重分表常驻，EXACT权重约147.6+283.8MiB，具体日志为准。
- 1080与900各12帧DIRECT_IO=3、Small AE开启的F9全回环。1080输出指针全程相同；900按处理尺寸重建，Process返回后新取输出并实际CopyResource/读回，未使用旧指针。第0/8帧Small SHA相同，全部帧finite，SuppressFps状态保持。
- 原网络1080 Gold仍`0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A`；Small仍`65D71486636715598EE1994166D5186A52D5F53230DBD7F8F03E514E3EC8FCB8`。每模型4-slot重复首尾均逐位一致。预热增加初始化帧，因此Pulse记录门计入1次warm，不用三帧Gold的含冷启动均值描述稳态性能。本热修不重复旧ABBA，也不声称新的提速幅度。
- runtime MODE1实际0.5→1→2→3→0.5通过。Onimusha别名进程的API完整帧测试确认flags选择`C:\XboxGames\Onimusha- Way of the Sword\Content\DLSS5-AMD`，真实游戏配置前后SHA未变。
- 调试层不可用；验证采用真实D3D12/HIP栅栏、资源使用、finite检查和字节回环。

## 双游戏安装与打包

双游戏已安装上述修正版，各80模块/93Small权重读回；已装runtime smoke exit0。备份`D:\DLSSNR-Lab\game-install-20261018-f9fix\backup-20261018-100728`，同根目录rollback.ps1可恢复修改前全部字节。详[安装回执](../game-install-20261018-f9fix/receipt.json)。正式0.44三包更新中，旧三包已核SHA保留到`D:\給網友打包\history\0.44-before-f9-20261018`；最终SHA见[发行页](../../releases/0.44/README.md)。

## 最终4764e4f1（-idle-r3）

最终host SHA在final-host-builds.json；此载荷取代前述6794构建。除原-idle-r2全门重新通过外，补充同尺寸MODE1：native post head初始化缓存两模型行、模型切换交换GPU行，更新blend且reset历史；history-row-cache-idle-r3 GPU读回32系数与对应模型一致，0.5→1→0.5均无错行。history-switch-1080-idle-r3第8帧与冷Original第2帧逐位相同，返回Small第13帧与原Small第2帧逐位相同；reset第0/12帧相同。Gold-r3仍0900/65D7，runtime-idle-r3也通过。

已重装最终4764e4f1，备份game-install-20261018-f9fix-r3/backup-20261018-102323，smoke0。[安装](../game-install-20261018-f9fix-r3/receipt.json)。最终三包44shader/RE9smoke/ZIP全文件与独立复验全部通过，新SHA见../../releases/0.44/README.md。GPU锁已释放。初轮误放行的排错数据保留，正式验收仅使用严格空闲-idle-r2/-idle-r3与gold-r3，最终产物以4764e4f1为准。
