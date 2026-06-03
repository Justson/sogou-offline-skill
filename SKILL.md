---
name: sogou-offline
description: 在 Windows 上限制搜狗输入法联网，同时尽量保留基础打字能力。用户要求屏蔽、限制、诊断、恢复搜狗输入法/搜狗拼音/搜狗 IME 联网时使用；包括 Windows 防火墙规则、本机代理 127.0.0.1:7890 绕过、防火墙拦不住、IFEO 启动拦截、拦截后弹窗闪屏、恢复基础输入服务、回滚相关改动。
---

# 搜狗输入法离线

这个 skill 用于处理 Windows 上搜狗输入法持续联网的问题，特别是搜狗通过本机代理继续访问网络的情况。优先使用内置 PowerShell 脚本，不要每次重新手写注册表和防火墙命令。

## 工作流

先设置 `$SkillDir` 为当前 skill 目录。常见位置：

```powershell
$SkillDir = "$env:USERPROFILE\.claude\skills\sogou-offline"
# 或者设置为这个仓库实际克隆的位置
```

1. 先检查状态：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action status
   ```
2. 添加普通防火墙拦截：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action firewall
   ```
3. 如果搜狗仍然能通过 `127.0.0.1:7890` 或其他本机代理联网，使用强化拦截：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action harden
   ```
4. 如果拦截后出现抢焦点、弹窗、黑框或闪屏，把拦截器切换为无窗口模式：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action fix-flash
   ```
5. 如果基础打字异常，只恢复搜狗基础服务，保留联网组件拦截：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action restore-service
   ```
6. 如果用户要撤销本 skill 创建的改动：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action revert
   ```

## 管理员权限

防火墙、IFEO 注册表、服务、计划任务通常需要管理员权限。如果直接运行返回拒绝访问，用管理员 PowerShell 启动：

```powershell
Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File', "$SkillDir\scripts\sogou-offline.ps1", '-Action', 'harden')
```

把 `harden` 换成用户需要的动作。

## 关键细节

- Windows 防火墙程序规则可能拦不住到 `127.0.0.1` 的本机回环连接，所以搜狗可以通过 `7890` 这类本机代理继续联网。
- `harden` 使用 IFEO `Debugger` 项阻止搜狗云输入、网页、助手、更新等组件启动。它不会刻意拦截 `SogouImeBroker.exe`。
- 不要用 `cmd.exe /c exit` 做 IFEO debugger，因为会造成抢焦点或控制台闪屏。遇到闪屏时运行 `fix-flash`，它会改成静默的 `wscript.exe //B` 拦截器。
- 不要禁用无关的代理、浏览器、聊天软件或系统防火墙规则，除非用户明确要求。
- 日志写入 `%USERPROFILE%\SogouOfflineSkill.log`。
