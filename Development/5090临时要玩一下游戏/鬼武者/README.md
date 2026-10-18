# 《鬼武者：剑之道》RTX 50 系原生 DLSS 5 直通包

适用于 **NVIDIA RTX 50 系显卡**（如 RTX 5090）运行《鬼武者：剑之道》（Xbox Game Pass / 微软商店版或 Steam 版）及《生化危机 9》等带反篡改校验的 RE Engine 游戏。

- **完整一键包下载（含 `310.9.16.0` 原版 `nvngx_dlssnr.dll`）**：
  - 夸克网盘：`https://pan.quark.cn/s/7ed3d027a675`（`Onimusha-DLSS5-RTX50-310.9.16.0.zip`）

## 目录文件说明

| 文件 | 说明 |
| :--- | :--- |
| `dinput8.dll` | REFramework（绕过卡普空 RE Engine 反篡改校验并加载同目录插件） |
| `dxgi.dll` | OptiScaler 宿主（自动识别 RTX 50 系显卡，走原生 NVIDIA NGX Feature 18 路径） |
| `OptiScaler.ini` | 配置文件（已设 `Dx12Upscaler=dlss`，`[DlssNr] Enabled=true, RunBeforeSR=true`） |
| `nvngx.dll_dlssnr.dll` | 开源 NGX 调用名转发桥（满足原版 `nvngx_dlssnr.dll` 对调用模块名含 `nvngx.dll` 的校验，源码见 `dlssnr_forwarder.cpp`） |
| `nvngx_dlssnr.dll` | NVIDIA 原版 DLSS 5 神经渲染运行库（`310.9.16.0`，默认启用 31 块新网络 `Preset 2`；体积 254 MB 本地保留，不入 Git，完整包见上方夸克链接） |

## 安装方法

将上述 5 个文件直接解压/复制到游戏 `.exe` 所在目录：
- **Xbox Game Pass 版**：`D:\XboxGames\Onimusha- Way of the Sword\Content\`（或 `C:\XboxGames\...`）
- **Steam 版**：游戏根目录（与 `OnimushaWotS.exe` 同级）

## 游戏内快捷键

- **`F6`**：实时开关 DLSS 5 神经渲染对比
- **`Insert`**：打开/关闭 OptiScaler 菜单（可在 `DLSS Neural Rendering` 面板调节 Pass 次数、强度或切换 Preset）
