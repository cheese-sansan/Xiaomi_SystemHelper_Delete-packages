---
name: manage-xiaomi-adb-packages
description: 在 Windows 上通过 ADB 检查、按用户卸载、禁用或恢复小米手机的四个指定组件：SystemHelper（com.mobiletools.systemhelper）、快应用服务框架（com.miui.hybrid）、RegService（com.miui.dmregservice）、GuardProvider（com.miui.guardprovider）。用户要求处理这些名称或包名，或提出“用 adb 删小米预装”“清理小米系统组件”等需要先澄清范围的请求时使用。不用于其他包、通用刷机或 root 操作。
---

# 小米组件 ADB 管理

仅处理用户指定且属于下表的包。默认先只读预检，再对明确确认的设备、Android 用户和包执行操作；默认不备份、不保留卸载包的应用数据、不重启。

## 1. 确定范围与操作

| 精确包名 | 常见名称 | 确认前告知的潜在影响 |
| --- | --- | --- |
| `com.mobiletools.systemhelper` | SystemHelper / System Helper | 用途可能随机型、ROM 或来源变化；不要与高通同名组件混淆 |
| `com.miui.hybrid` | 快应用服务框架 | 快应用及相关入口可能不可用 |
| `com.miui.dmregservice` | RegService / 设备注册服务 | 设备注册及相关联网服务可能受影响；涉及通信功能时谨慎处理 |
| `com.miui.guardprovider` | GuardProvider | 安全扫描或安全中心相关能力可能受影响 |

不要仅凭包名断言组件安全、恶意或必然影响 SIM、APN、VoLTE；具体影响取决于设备与系统版本。绝不处理 `com.qualcomm.qti.services.systemhelper`、`com.miui.securitycenter`、`com.miui.powerkeeper` 等相近或相关包。

- **只检查**：仅查询，不下载工具、不卸载、不禁用、不恢复。
- **指定一个或几个包**：仅处理这些包，不扩大到四包。
- **明确全部四包**：才将四包纳入候选范围；已是目标状态的包无需写操作。
- **范围含糊**：先询问包名及要检查、卸载还是禁用，不默认全删。
- **要求禁用**：使用禁用命令，不替换为卸载。
- **要求保留数据、备份或恢复**：先明确方式与限制；未经确认不执行。APK 备份不等于应用数据备份，也不能承诺无损恢复。
- **要求重启或处理范围外的包**：说明不属于本 Skill 的默认流程，单独确认并处理，不夹带执行。

## 2. 准备 ADB 与只读预检

优先使用用户提供的 `adb.exe`，其次检查 PATH 和 `%LOCALAPPDATA%\Qoder\AndroidPlatformTools\platform-tools\adb.exe`。没有 ADB 时明确说明“预检未完成”，请用户提供路径，或取得同意后仅安装官方 Platform-Tools，再重新预检。不得为了安装 ADB 而启动卸载脚本。

以下示例为 **PowerShell**，不要直接作为 Git Bash 命令执行。通过 Bash 工具调用时用 `powershell.exe -NoProfile -Command '…'` 承载 PowerShell 内容，并正确保护引号与 `$` 变量；已有脚本用 `-File`。不要添加 `-ExecutionPolicy Bypass` 或修改执行策略来绕过限制。

将 `<ADB完整路径>` 等占位符替换为实际值，先运行：

```powershell
$adb = '<ADB完整路径>'
& $adb devices -l
```

- 无设备、`unauthorized`、`offline` 或非正常启动状态：停止，先解决连接问题。
- 多台设备：让用户选择目标，不根据列表顺序猜测。内部记录序列号，汇报时只给必要的设备信息，避免完整披露序列号。
- 后续每条设备命令都带 `-s`，固定同一设备。记录型号、系统版本与当前 Android 用户编号，不假设用户编号是 `0`。

```powershell
$serial = '<选定设备序列号>'
& $adb -s $serial shell getprop ro.product.model
& $adb -s $serial shell getprop ro.build.version.release
& $adb -s $serial shell am get-current-user
```

将返回的非负整数写入 `$userId`。每次新 PowerShell 调用都需重新设置所用变量，不依赖前一次进程的变量。

对范围内每个包分别查询，检查退出码与错误文本，并用完整包名精确匹配 `package:<包名>`，不要把过滤器的子串匹配当作精确结果：

```powershell
$userId = <已验证的用户编号>
$package = '<允许列表中的精确包名>'
& $adb -s $serial shell pm list packages --user $userId $package
& $adb -s $serial shell pm list packages -d --user $userId $package
```

第一条正常完成且有精确匹配才表示该用户已安装；第二条有精确匹配表示已禁用。不要加 `-u` 来验证是否卸载成功，它会包含已卸载包。查询失败、权限错误或不支持 `--user` 时，状态为“未知”，停止写操作，不当作“已不存在”，也不退回不指定用户的查询。

需要定位 APK 时可另查 `pm path --user <用户编号> <包名>`，但不要仅凭路径判断按用户卸载成功，更不要把无路径解释为系统分区文件已删除。

## 3. 汇总并一次确认

列出目标设备、当前用户、精确包名、当前状态和计划动作。无包需要变更时直接结束；待恢复但该用户未安装的包不属于“无需变更”。

写操作前一次性确认完整范围与影响：卸载默认不带 `-k`，会请求删除该用户的应用数据；禁用不等于卸载；默认不备份、不重启；恢复安装不会恢复已删除的数据。包含安全或注册组件时提示上表对应风险。

用户确认后不逐包重复询问，但不能跳过工具本身的权限审批。若设备、当前用户、操作方式或待处理范围改变，停止并重新预检、确认，不沿用旧授权。

## 4. 逐包执行并验证

开始写操作前及每个后续包操作前，确认目标仍在线，且 `am get-current-user` 仍等于已确认的 `$userId`。只执行用户确认的操作：

| 操作 | PowerShell 命令 |
| --- | --- |
| 按用户卸载，默认不保留数据 | `& $adb -s $serial shell pm uninstall --user $userId $package` |
| 按用户卸载，明确要求保留数据 | `& $adb -s $serial shell pm uninstall -k --user $userId $package` |
| 禁用 | `& $adb -s $serial shell pm disable-user --user $userId $package` |
| 恢复仍留在系统中的包 | `& $adb -s $serial shell cmd package install-existing --user $userId $package` |
| 重新启用已禁用包 | `& $adb -s $serial shell pm enable --user $userId $package` |

不要拼接用户任意输入执行命令；包名必须取自上表，序列号来自设备列表，用户编号必须经过验证。

每处理一个包，立即按第 2 节重新查询同一设备、同一用户：

- **卸载**：命令返回 `Success` 且已安装列表不再精确匹配，才计入“卸载并验证成功”。
- **禁用**：命令正常完成，且已安装列表与禁用列表都精确匹配。
- **恢复安装**：命令正常完成，且已安装列表精确匹配；如果仍禁用，如实说明，未获启用授权不要追加 `pm enable`。
- **启用**：命令正常完成，已安装列表精确匹配，且禁用列表不再匹配。

退出码非零、返回 `Failure`、输出异常、连接中断或验证不符时立即停止余下写操作，保留原始错误。不要自动重试整批，不自动回滚，也不把已有成功操作说成未发生。

`Failure [not installed for N]` 也先停止；仅在重新查询确认 N 等于目标用户、且该用户确实未安装后，记为“已不存在”，不能记为本次卸载成功。继续剩余操作前重新核对状态与授权范围。

## 5. 汇报与异常处理

按实际记录分别列出：成功且验证通过、原本已是目标状态、失败或状态未知、尚未执行。未运行或失败中断的查询不计入验证通过；不编造脚本汇总。

如果发生变更，请用户检查解锁、SIM 信号、移动数据；涉及注册服务时补充相关通话测试，涉及 GuardProvider 时补充安全扫描检查。用户检查前仅宣称“包状态验证通过”，不要宣称“系统功能全部正常”。

| 现象 | 下一步 |
| --- | --- |
| `unauthorized` | 请用户解锁手机并允许此电脑 USB 调试，然后重新预检 |
| `offline` / 无设备 | 检查数据线、接口和 USB 调试；不要擅自重启设备或终止其他 ADB 会话 |
| `DELETE_FAILED_USER_RESTRICTED` / `DELETE_FAILED_DEVICE_POLICY_MANAGER` | 如实报告系统或管理策略限制，停止，不绕过策略 |
| ADB 缺失 / 工具下载失败 | 请用户提供 ADB 路径或确认单独安装；不要继续卸载 |
| PowerShell 策略阻止脚本 | 报告原因，由用户决定如何调整，不自动绕过 |
| `install-existing` 失败 | 核实设备仍有该包；不要下载来源不明的 APK，也不要直接建议恢复出厂设置 |
| 变更后功能异常 | 停止后续操作，说明可恢复的包与数据限制，取得确认后逐包恢复并验证 |

## 配套脚本的使用限制

`scripts/remove-xiaomi-packages.ps1` 是现有四包卸载脚本，仅支持 `-AdbPath`、`-ToolDirectory` 及 PowerShell 通用参数，没有包筛选、禁用或恢复参数。不要虚构参数。

当前版本存在以下限制：包查询未指定 `--user`；设备命令未用 `-s` 固定目标；运行中未核对当前用户是否变化；异常退出时没有最终汇总；缺少 ADB 时 `-WhatIf` 会跳过全部设备检查，而正式执行会安装工具后继续卸载。

因此本 Skill 默认使用上面的显式定向命令；在这些限制修复并验证前，不用该脚本执行写操作。仅当用户明确要检查全部四包、且理解结果不能代替按用户预检时，可参考其输出：

```powershell
powershell.exe -NoProfile -File "<skill-base-directory>\scripts\remove-xiaomi-packages.ps1" -WhatIf -AdbPath "<ADB完整路径>"
```

`<skill-base-directory>` 使用本 Skill 的实际目录。`-WhatIf` 不卸载、不下载，但 ADB 查询可能启动本机 ADB 服务或触发手机授权弹窗；不要承诺完全没有本机副作用。部分包请求不要运行四包脚本。

## 不可越过的边界

- 不执行 root、`su`、`remount`、`pm clear`、手机端文件删除、刷机或绕过设备管理策略。
- 不物理删除 `/system`、`/product` 中的 APK，不触碰其他用户或共享目录。
- 按用户卸载不等于从整台设备彻底删除；不承诺清理共享 UID、其他应用文件或释放系统分区空间。
- 只在 APK 仍可供系统安装时说明可用 `install-existing` 恢复；已删除的数据不随恢复安装返回。恢复与启用也必须先预检、再确认。
