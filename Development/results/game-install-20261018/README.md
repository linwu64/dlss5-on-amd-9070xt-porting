# 0.44 双游戏安装（2026-10-18 05:02）

正式三包及功能验收完成、源码提交后，持D:\DLSSNR-Lab\gpu.lock完成本轮明确授权的双游戏部署。每个修改文件先备份/读回校验，再安装/读回校验；15秒game-check看门狗，完成已释放锁。

- 《剑星》更新addon、80模块、93 Small权重及边界shader。
- 《鬼武者》更新根目录和_storage_两个runtime、80模块、93 Small权重及边界shader；已安装runtime smoke exit0，日志effective=0.5x/blocks31。
- 三层MP设0.5；custom/native设HOT1/F9，其他个人项保留。《剑星》MODE0，《鬼武者》MODE1。
- 修改前《剑星》custom/native为MP2，《鬼武者》为MP1；备份保留各自完整原始字节。

备份：`D:\DLSSNR-Lab\game-install-20261018\backup-20261018-050250`。执行`rollback.ps1`可逐项恢复/删除全部修改项，并核验原SHA；回滚前须退出游戏，脚本同样持锁并检查游戏。脚本尚未执行回滚，当前保持新版0.44。

[安装SHA与配置](receipt.json) · [原文件备份清单](backup-manifest.json) · [回滚脚本](rollback.ps1)。实玩观感留Zero验收，没有代开游戏。
