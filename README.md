# Xiaomi_SystemHelper_Delete packages

一个面向 **Qoder Desktop** 的小米设备组件 ADB 管理 Skill。它将 SystemHelper、快应用服务框架、RegService 和 GuardProvider 四个指定组件的检查、按用户卸载、禁用与恢复收敛到明确的安全流程中，避免无差别“一键精简”。

> GitHub 仓库名为 `Xiaomi_SystemHelper_Delete-packages`；仓库名中的空格以连字符代替。

## 项目特点

- **范围固定**：只处理四个精确包名，不根据相似名称扩大范围。
- **先检查后操作**：默认进行只读预检，确认设备、Android 当前用户、组件状态与计划动作。
- **一次确认完整范围**：写操作前集中说明目标、影响和限制，不夹带未授权操作。
- **支持多种动作**：可按用户卸载、禁用、恢复安装或重新启用，不将禁用与卸载混为一谈。
- **逐项验证**：每个组件操作后立即复查；遇到异常、连接中断或结果不符时停止后续写操作。
- **不依赖 Root**：使用 Android 官方 ADB 包管理能力，不刷机、不重挂载系统分区、不物理删除系统 APK。

## 支持的组件

| 精确包名 | 常见名称 | 可能的影响 |
| --- | --- | --- |
| `com.mobiletools.systemhelper` | SystemHelper / System Helper | 用途可能随机型、ROM 或来源变化；不要与高通同名组件混淆 |
| `com.miui.hybrid` | 快应用服务框架 | 快应用及相关入口可能不可用 |
| `com.miui.dmregservice` | RegService / 设备注册服务 | 设备注册及相关联网服务可能受影响；涉及通信功能时需谨慎 |
| `com.miui.guardprovider` | GuardProvider | 安全扫描或安全中心相关能力可能受影响 |

本项目不会处理 `com.qualcomm.qti.services.systemhelper`、`com.miui.securitycenter`、`com.miui.powerkeeper` 等相近或相关包，也不会仅凭包名断言某个组件是恶意的或对设备必然安全。

## 环境要求

- Windows 与 PowerShell
- 支持 Skills 的 Qoder Desktop
- Android 官方 Platform-Tools 中的 `adb.exe`
- 一台由你所有或明确获授权操作的小米设备
- 已在设备上开启 USB 调试，并授权当前电脑连接

无需 Root。多设备同时连接时，Skill 会要求先选定目标，不会根据列表顺序猜测设备。

## 安装

### 1. 克隆仓库

```powershell
git clone https://github.com/cheese-sansan/Xiaomi_SystemHelper_Delete-packages.git
```

### 2. 安装为 Qoder Skill

将仓库中的 `SKILL.md` 和 `scripts/` 放入以下目录：

```text
%USERPROFILE%\.qoder\skills\manage-xiaomi-adb-packages\
```

如果本机已有同名 Skill，请先保留你的修改，再决定是否替换。安装后按 Qoder Desktop 的 Skills 管理方式重新加载；未被识别时可重启应用。

## 使用方式

在 Qoder 中直接描述需要的操作。建议从只读检查开始：

```text
只检查 SystemHelper 和快应用服务框架的状态，不做任何修改。
```

指定组件和动作：

```text
检查并卸载 com.mobiletools.systemhelper，仅处理当前 Android 用户。
```

```text
禁用 com.miui.hybrid，不要卸载其他组件。
```

```text
检查 com.miui.guardprovider，并在确认后重新启用它。
```

如果请求只是“清理小米预装”等含糊描述，Skill 会先澄清组件与动作，不会默认删除全部四个包。

### 标准操作流程

1. 查找或确认 `adb.exe`，执行设备连接检查。
2. 固定目标设备序列号，读取型号、系统版本和当前 Android 用户编号。
3. 对指定组件分别查询已安装与禁用状态。
4. 汇总设备、用户、组件状态、计划动作及潜在影响，请求一次确认。
5. 仅执行已确认的操作，并在每个组件处理后立即验证。
6. 分别报告成功、原本已是目标状态、失败或未知、尚未执行的项目。

## 配套 PowerShell 脚本

仓库保留了 `scripts/remove-xiaomi-packages.ps1`。它面向全部四个组件，仅支持 `-AdbPath`、`-ToolDirectory` 及 PowerShell 通用参数，**不支持包筛选、禁用或恢复参数**。

当前版本存在以下限制：

- 包查询未指定 `--user`，不能代替按用户预检。
- 设备命令未使用 `-s` 固定目标。
- 运行中未核对当前 Android 用户是否变化。
- 异常退出时没有最终汇总。
- 缺少 ADB 时，`-WhatIf` 会跳过设备检查，而正式执行可能下载工具后继续卸载。

因此，在这些限制修复并验证前，**不要将配套脚本用于写操作**。只有明确需要检查全部四个组件、并理解其局限时，才可参考以下只读预检命令：

```powershell
powershell.exe -NoProfile -File ".\scripts\remove-xiaomi-packages.ps1" -WhatIf -AdbPath "C:\path\to\adb.exe"
```

`-WhatIf` 不执行卸载或下载，但 ADB 查询可能启动本机 ADB 服务或触发手机授权弹窗。部分组件的请求不要运行这个四包脚本。

完整操作规范、命令示例和异常处理规则请参阅 [SKILL.md](SKILL.md)。

## 重要限制与风险

- 按用户卸载只会移除指定 Android 用户下的包，不等于从系统分区彻底删除 APK。
- 默认卸载命令不保留该用户的应用数据；默认不备份、不重启。
- `install-existing` 只适用于 APK 仍留在系统中的包，恢复安装不会找回已删除的数据。
- 组件的实际用途与影响取决于机型、MIUI / HyperOS 版本和 ROM 来源，本项目不保证设备功能不受影响。
- 遇到 `DELETE_FAILED_USER_RESTRICTED`、设备策略限制或 PowerShell 执行策略阻止时，不会尝试绕过。
- 操作后应自行检查解锁、SIM 信号、移动数据及相关功能；涉及注册服务时还应检查通话，涉及 GuardProvider 时还应检查安全扫描。

请仅在你理解影响并接受风险后执行写操作。重要的个人数据应通过你信任的独立方式提前备份。

## 项目结构

```text
.
├── SKILL.md                              # Skill 定义与完整安全流程
├── scripts/
│   └── remove-xiaomi-packages.ps1        # 现有的四包脚本，当前仅建议只读预检
├── LICENSE                               # MIT 开源许可
└── README.md                             # 项目介绍
```

## 参与贡献

欢迎通过 Issue 或 Pull Request 改进按用户状态检测、多设备固定、脚本验证、异常汇总和文档。提交问题时请提供必要的设备型号、系统版本、ADB 输出与复现步骤，并隐藏完整设备序列号及其他个人信息。

贡献代码时请保持组件范围明确，不加入 Root、刷机、绕过设备管理策略、来源不明 APK 下载或无差别批量卸载能力。

## 开源许可

本项目基于 [MIT License](LICENSE) 开源。
