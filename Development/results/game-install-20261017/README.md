# 《剑星》与《鬼武者》本机游戏安装记录（`game-install-20261017`）

- **日期**：2026-10-17 23:36
- **载荷源码基线**：`10982cf4`（最终提交 `135463e0`，含 2026-10-14 全部七场战役 + 2026-10-17 验收合入的 Block 47→`Up(48)` 1B E4M3 字节边、`Up(39)`/`Up(48)` W16 FP8 WMMA 及 `Down(8/14/22/30)` `mh_pool_project_group` 1B E4M3 LDS + W16 FP8 WMMA）
- **备份与一键回滚**：
  - 备份目录：`D:\DLSSNR-Lab\game-install-20261017\backup-20261017-233600`（含 `game-0` 剑星与 `game-1` 鬼武者的原二进制、模块及 `manifest.json`）
  - 一键回滚脚本：`D:\DLSSNR-Lab\game-install-20261017\rollback.ps1`（已同步归档于本目录 [rollback.ps1](rollback.ps1)）

## 1.《剑星》（Stellar Blade）安装核验
- **目标路径**：`C:\Program Files (x86)\Steam\steamapps\common\StellarBlade\SB\Binaries\Win64`
- **`dlss5-amd.addon64`**：
  - 替换前 SHA256：`91d8147188b950367d40ed041588a0591ccbc0d4627ff70702b9a4e68eb0cd26`（10-14 版 `be506729`）
  - 替换后 SHA256：`2cefc60d50906d9a5dcf542f1c890819fcaa01b2d712047423d303b8f0475e5b`（读回校验一致）
- **HIP 模块**：`DLSS5-AMD\native-game-tiled-assets\HIP` 下 `gfx1200`（40 个）+ `gfx1201`（40 个）共 **80 个 `.hsaco`** 全部更新并通过 SHA256 逐文件读回校验（`SHA256SUMS` 哈希 `ea2e5abadc361fda9c74a421ef8015c8709e7b2292330e5932feafd355327335`）。
- **个人配置保留**：`default-config.txt`、`custom-config.txt`（`MODE0 / MP1 / PREDICT1 / SKIN0 / 1x`）、`native-game-flags.txt` 字节哈希 100% 未改动。

## 2.《鬼武者》（Onimusha: Way of the Sword）安装核验
- **目标路径**：`C:\XboxGames\Onimusha- Way of the Sword\Content`
- **`LmxxfNrRuntime.dll`（含 `_storage_\LmxxfNrRuntime.dll` 同步更新）**：
  - 替换前 SHA256：`50c3b80b730fce925c65c83a803c42406e6644f03e0fb0ae71535bbd88567844`
  - 替换后 SHA256：`bc7b77049f828e1500bfe447d9f09c963b38b2c5584c104f65650e5127f8decd`（两处均通过读回校验）
- **HIP 模块**：`DLSS5-AMD\native-game-tiled-assets\HIP` 下 `gfx1200`（40 个）+ `gfx1201`（40 个）共 **80 个 `.hsaco`** 全部更新并通过 SHA256 逐文件读回校验。
- **个人配置保留**：`default-config.txt`、`custom-config.txt`（`MODE1 / MP1 / PREDICT0 / SKIN0`）、`native-game-flags.txt` 字节哈希 100% 未改动。
- **Runtime 冒烟验证（`runtime-smoke.exe`）**：
  - `PrepareFrame rc=0`，`HIP rc=0`，`SP_STATS runs=4 fallback=0 rollover=0 jobs=2496 disabled=0 errors=0`，`lmxxf_nr_gpu: ok`（`exit=0`）。
