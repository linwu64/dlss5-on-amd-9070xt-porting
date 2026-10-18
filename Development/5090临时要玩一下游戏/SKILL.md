---
name: 5090-dlss5-game-install
description: 在 RTX 5090 (ssh rtx5090) 机器上为游戏安装原生 NVIDIA DLSS 5 (310.9.16.0)，并归档打包。不要去查复杂的插件逆向，直接把我们现成的壳子配原版 nvngx_dlssnr.dll 拷过去就行！
---

# RTX 5090 游戏安装原生 DLSS 5 极简手册（给朱雀自己看的防绕弯 Skill）

> **⚠️ 第一铁律：别把简单事搞复杂！**
> 给 5090 装 DLSS 5 **本质上就是把我们在 9070 上用熟的那套壳子（OptiScaler / REFramework / ReShade）拿过来，底下不放 AMD 的 `LmxxfNrRuntime.dll`，直接放老黄原版的 `nvngx_dlssnr.dll`（`310.9.16.0`）！**
> 收到指令后 **30 秒内直接拷文件装完**，严禁再去扫几十个目录查导入表！

---

## 1. 机器与现成文件坐标

- **目标机器 SSH**：`ssh rtx5090`（`192.168.31.50`，用户 `seth`）
  - **Steam 游戏库**：`D:\SteamLibrary\steamapps\common\`
  - **Xbox / XGP 游戏库**：`D:\XboxGames\<游戏名>\Content\`
  - **5090 本机现成的最新原版 DLSS 5 DLL（`310.9.16.0`，31 块新模型 Preset 2 默认）**：
    - `C:\DLSSNR-Small-20261018\new\nvngx_dlssnr.dll`（266,424,944 字节，SHA256 `2BC19BC09A7B89DD44F73E2AC0108FCC586E2154BDD0830F242F4F040E28789F`）
  - **5090 本机旧版原版 DLSS 5 DLL（`310.8.0.0`，71 块旧模型）**：
    - `C:\DLSSNR-Small-20261018\old\nvngx_dlssnr.dll`（165,840,496 字节）

- **DGX 本机现成壳子仓库**：
  - `/home/lmxxf/work/ai-theorys-study/wechat/assets/297/Development/5090临时要玩一下游戏/鬼武者/`
  - 里面已经有全套现成文件：
    1. **`dxgi.dll`**（25 MB）：OptiScaler 宿主。**只要同目录没有 `LmxxfNrRuntime.dll` 且显卡是 NVIDIA，它会自动走原版 NVIDIA NGX Feature 18 直通路径！**
    2. **`OptiScaler.ini`**（47 KB）：已配好 `Dx12Upscaler=dlss`、`[DlssNr] Enabled=true, RunBeforeSR=true`。
    3. **`nvngx.dll_dlssnr.dll`**（102 KB）：NGX 调用名转发桥（老黄的 `nvngx_dlssnr.dll` 会校验调用它的模块名必须含 `nvngx.dll`，OptiScaler 靠这个小 DLL 转发调用，**必须和 `dxgi.dll` 一起放**）。
    4. **`dinput8.dll`**（22 MB）：REFramework（仅卡普空 RE Engine 游戏需要，用来绕过反篡改校验并加载同目录 `dxgi.dll`）。
    5. **`nvngx_dlssnr.dll`**（254 MB）：原版 `310.9.16.0` DLL。

---

## 2. 按游戏类型一键安装（二选一）

先找准游戏真正的 `.exe` 所在目录（注意 UE 游戏通常在 `<Game>\Binaries\Win64\`，Xbox 游戏在 `D:\XboxGames\<Game>\Content\`）。

### 路线 A：通用 DX12 游戏 + 卡普空 RE Engine 游戏（首选 OptiScaler 路线）

- **常规 DX12 游戏**（如《黑神话》《剑星》等）：
  直接往游戏 `.exe` 同级目录放 **4 个文件**：
  - `dxgi.dll`
  - `OptiScaler.ini`
  - `nvngx.dll_dlssnr.dll`
  - `nvngx_dlssnr.dll`（直接从 5090 本机 `C:\DLSSNR-Small-20261018\new\nvngx_dlssnr.dll` 复制过去最快，省得跨网传 254 MB）

- **卡普空 RE Engine 游戏**（如《鬼武者：剑之道》《生化危机 9》）：
  在上面 4 个文件基础上，**多加 1 个 `dinput8.dll`**（共 **5 个文件**）。

**一行命令模板（从 DGX 执行）**：
```bash
# 1. 把小壳子传过去（如果是 RE Engine 游戏就带上 dinput8.dll，普通游戏去掉 dinput8.dll）
scp /home/lmxxf/work/ai-theorys-study/wechat/assets/297/Development/5090临时要玩一下游戏/鬼武者/{dinput8.dll,dxgi.dll,OptiScaler.ini,nvngx.dll_dlssnr.dll} "rtx5090:D:/目标游戏exe目录/"

# 2. 在 5090 本机直接把 310.9.16.0 的 nvngx_dlssnr.dll 拷进游戏目录
ssh rtx5090 'powershell -NoProfile -Command "Copy-Item C:\DLSSNR-Small-20261018\new\nvngx_dlssnr.dll \"D:\目标游戏exe目录\nvngx_dlssnr.dll\" -Force"'
```

- **游戏内设置与快捷键**：
  - 游戏画面设置里开启 **DLSS 超分辨率**。
  - **`F6`**：开关 DLSS 5 神经渲染。
  - **`Insert`**：呼出 OptiScaler 菜单（可在 `DLSS Neural Rendering` 下调 Pass 次数、强度、Preset）。

---

### 路线 B：不开 DLSS 或纯后处理注入的游戏（ReShade + RenoDX / AIO 路线）

如果某个游戏没有内置 DLSS 超分，或者想用纯 ReShade 后置注入，5090 本机《剑星》目录和 `D:\work\aio\` 里有现成件：
- ReShade 主程序：`D:\SteamLibrary\steamapps\common\StellarBlade\SB\Binaries\Win64\d3d12.dll`（改名为 `dxgi.dll` 或 `d3d12.dll`）
- 独立插件包：`D:\work\aio\x\`（含 `standalone-dlssnr.addon64` + `nvngx.dll` + `reshade-shaders`），参考 `D:\work\aio\install-aio.ps1`。

---

## 3. 归档、打包与 Git 提交规矩

当 Zero 说“归档 / 打包放云盘 / commit”时，按以下固定动作执行：

1. **建游戏子目录**：
   在 `/home/lmxxf/work/ai-theorys-study/wechat/assets/297/Development/5090临时要玩一下游戏/<游戏名>/` 下放好本次用到的壳子文件 + `README.md`。
2. **打 ZIP 包并传到 9070 的打包目录**：
   - 将包含 `nvngx_dlssnr.dll` 在内的完整文件打包为 `.zip`。
   - 用 `scp` 传到 `amd9070:D:/給網友打包/`，方便 Zero 上传夸克网盘。
3. **Git Commit 铁律**：
   - **绝对不要把 254 MB 的 `nvngx_dlssnr.dll` 和 `.zip` 提交进 Git！**（`.gitignore` 已配好忽略 `Development/5090临时要玩一下游戏/**/nvngx_dlssnr.dll` 和 `*.zip`）。
   - 等 Zero 给出夸克网盘链接后，把链接写进 `<游戏名>/README.md`，然后 `git add` 除 `nvngx_dlssnr.dll` 以外的壳子文件与 `README.md`，commit（不加 `Co-Authored-By`）并 `git push origin main`。
