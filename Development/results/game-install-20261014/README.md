# 《剑星》与《鬼武者》本机游戏安装记录（`game-install-20261014`）

- **日期**：2026-10-14 23:36
- **载荷源码基线**：`be506729`（含 2026-10-14 全部已验收优化：C512 主干 W16 `02626c84`、C512 Split-FFN W16 `411db2ed`、C32 Wave1 W16 `3a465687`、ViT W16 `cff1f054`、全网 Epilogue 无分支与 `v_movrel` 清理 `d5b72614`、二轮 ISA 向量化 `9241808a`、ViT 块间 1B 字节流 `e337af3d`、C512/Down/ViT 全边界 1B 字节流 `be506729` `HIP_VIT_INTER_BYTE=15` 及 `NativeLowFrequencyTemporal` 64-slot ring `66981ef1`）
- **备份与一键回滚**：
  - 备份目录：`D:\DLSSNR-Lab\game-install-20261014\backup-20261014-233615`（含 `game-0` 剑星与 `game-1` 鬼武者的原二进制、模块及 `manifest.json`）
  - 一键回滚脚本：`D:\DLSSNR-Lab\game-install-20261014\rollback.ps1`（已同步归档于本目录 [rollback.ps1](rollback.ps1)）

## 1.《剑星》（Stellar Blade）安装核验
- **目标路径**：`C:\Program Files (x86)\Steam\steamapps\common\StellarBlade\SB\Binaries\Win64`
- **`dlss5-amd.addon64`**：
  - 替换前 SHA256：`64dc04286c22d5d378a70013f986c98c8d26a55a53feaf02ba682c4301ca8483`（10-12 紧凑权重版 `1b4c898f`）
  - 替换后 SHA256：`91d8147188b950367d40ed041588a0591ccbc0d4627ff70702b9a4e68eb0cd26`（读回校验一致）
- **HIP 模块**：`DLSS5-AMD\native-game-tiled-assets\HIP` 下 `gfx1200`（40 个）+ `gfx1201`（40 个）共 **80 个 `.hsaco`** 全部更新并通过 SHA256 逐文件读回校验（`SHA256SUMS` 哈希 `d864d3937e3a9cdf029343ee2d11ef2204a76ee30ab238977ebbeea08d155942`）。
- **个人配置保留**：`default-config.txt`、`custom-config.txt`（`MODE0 / MP1 / PREDICT0 / SKIN0 / 1x`）、`native-game-flags.txt` 字节哈希 100% 未改动。

## 2.《鬼武者》（Onimusha: Way of the Sword）安装核验
- **目标路径**：`C:\XboxGames\Onimusha- Way of the Sword\Content`
- **`LmxxfNrRuntime.dll`（含 `_storage_\LmxxfNrRuntime.dll` 同步更新）**：
  - 替换前 SHA256：`3eaed204f5d6ad803749d6e8c79ed1e79c514f5d02ef1e68d8dcb3f292638db6`
  - 替换后 SHA256：`50c3b80b730fce925c65c83a803c42406e6644f03e0fb0ae71535bbd88567844`（两处均通过读回校验）
- **HIP 模块**：`DLSS5-AMD\native-game-tiled-assets\HIP` 下 `gfx1200`（40 个）+ `gfx1201`（40 个）共 **80 个 `.hsaco`** 全部更新并通过 SHA256 逐文件读回校验。
- **个人配置保留**：`default-config.txt`、`custom-config.txt`（`MODE1 / MP1 / PREDICT0 / SKIN0`）、`native-game-flags.txt` 字节哈希 100% 未改动。
- **Runtime 冒烟验证（`runtime-smoke.exe`）**：
  - `PrepareFrame rc=0`，`HIP rc=0`，`SP_STATS runs=4 fallback=0 rollover=0 jobs=2496 disabled=0 errors=0`，`lmxxf_nr_gpu: ok`（`exit=0`）。

## 3. 用户实玩反馈（2026-10-15 00:14）
- 用户原话：“试了一下， 剑星 稳定在60帧了。”（此前 10-12 紧凑权重版 `64dc0428…` 同为 `MODE0 / MP1 / 1x` 静态画面为 58.2 帧）。

