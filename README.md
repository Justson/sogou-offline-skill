# 搜狗输入法离线 Skill

`sogou-offline` 是一个用于限制搜狗输入法联网的 Windows agent skill。目标是尽量保留基础打字能力，同时拦住云输入、助手、更新、网页渲染、下载等联网组件。

它处理普通防火墙规则经常漏掉的情况：

- 搜狗云输入、智能助手、语音助手、更新、下载、网页渲染等组件
- 通过本机代理绕过防火墙，例如 `127.0.0.1:7890`
- 拦截启动后反复抢焦点、弹黑框、闪屏的问题
- 基础输入异常时的局部恢复
- 一键回滚本 skill 创建的规则和拦截项

## 兼容性

仓库使用通用 skill 结构：

```text
sogou-offline/
├── SKILL.md
├── agents/
│   └── openai.yaml
└── scripts/
    └── sogou-offline.ps1
```

Claude 可以读取带 YAML `name` 和 `description` 的 `SKILL.md`。Claude Code 建议安装到：

```text
~/.claude/skills/sogou-offline/
```

其他能读取 `SKILL.md` 的 agent 也可以直接使用这个目录。

## 安装

克隆到 Claude skills 目录：

```powershell
git clone git@github.com:Justson/sogou-offline-skill.git "$env:USERPROFILE\.claude\skills\sogou-offline"
```

也可以克隆到任意位置，然后在运行命令前设置 `$SkillDir`：

```powershell
$SkillDir = "C:\path\to\sogou-offline"
```

## 用法

查看当前状态：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action status
```

添加 Windows 防火墙规则：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action firewall
```

如果搜狗仍然能通过本机代理联网，使用更强的拦截：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action harden
```

如果拦截后出现弹窗、黑框或闪屏：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action fix-flash
```

如果基础打字受到影响，只恢复搜狗基础服务：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action restore-service
```

撤销本 skill 创建的防火墙和启动拦截：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action revert
```

## 管理员权限

防火墙、注册表、服务、计划任务相关操作通常需要管理员权限。可以这样以管理员身份运行：

```powershell
Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File', "$SkillDir\scripts\sogou-offline.ps1", '-Action', 'harden')
```

## 注意事项

- Windows 防火墙的程序规则通常拦不住本机回环流量，所以搜狗可能通过本机代理继续联网。
- `harden` 会用 IFEO 启动拦截阻止搜狗联网组件启动。
- `SogouImeBroker.exe` 会被保留，不会被刻意拦截，因为它通常是基础输入法加载所需。
- 日志写入 `%USERPROFILE%\SogouOfflineSkill.log`。
