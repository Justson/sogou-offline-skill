# Sogou Offline

`sogou-offline` is an agent skill for restricting Sogou Input Method network access on Windows while keeping basic typing available.

It handles the cases that simple firewall rules often miss:

- Sogou cloud, assistant, update, web-rendering, and download components
- Local proxy bypass through loopback addresses such as `127.0.0.1:7890`
- Focus-stealing console flashes caused by visible process blockers
- Rollback and partial recovery when basic input behavior is affected

## Compatibility

This repository uses the common skill layout:

```text
sogou-offline/
├── SKILL.md
├── agents/
│   └── openai.yaml
└── scripts/
    └── sogou-offline.ps1
```

Claude can use the skill because it has a `SKILL.md` file with YAML `name` and `description` frontmatter. For Claude Code, install it at:

```text
~/.claude/skills/sogou-offline/
```

Other agents that read `SKILL.md` can use the same folder directly.

## Install

Clone the repository into your skills directory:

```powershell
git clone git@github.com:Justson/sogou-offline-skill.git "$env:USERPROFILE\.claude\skills\sogou-offline"
```

Or clone it anywhere and set `$SkillDir` to that folder before running commands:

```powershell
$SkillDir = "C:\path\to\sogou-offline"
```

## Usage

Check current state:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action status
```

Add Windows Firewall rules:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action firewall
```

Apply stricter blocking for local proxy bypass:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action harden
```

Fix popup or console flashing after hardening:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action fix-flash
```

Restore the basic Sogou service if typing is affected:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action restore-service
```

Undo firewall and launch-blocking changes created by this skill:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action revert
```

## Administrator Rights

Firewall, registry, service, and scheduled-task changes normally require Administrator rights. To run an action elevated:

```powershell
Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File', "$SkillDir\scripts\sogou-offline.ps1", '-Action', 'harden')
```

## Notes

- Windows Firewall program rules may not block loopback traffic to a local proxy.
- The hardening action uses IFEO launch blockers for Sogou network components.
- `SogouImeBroker.exe` is intentionally not blocked so the core input method can still load.
- Logs are written to `%USERPROFILE%\SogouOfflineSkill.log`.
