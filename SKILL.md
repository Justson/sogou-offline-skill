---
name: sogou-offline
description: Restrict Sogou Input Method network access on Windows while preserving basic typing. Use when a user asks to block, limit, harden, restore, or diagnose Sogou/Sogou Pinyin/Sogou IME networking, including Windows Firewall rules, localhost proxy bypass via 127.0.0.1:7890, IFEO launch blocking, flickering popup/console flashes caused by blockers, or rollback of these changes.
---

# Sogou Offline

Use this skill for Windows machines where Sogou Input Method keeps reaching the network, especially through a local proxy. Prefer the bundled PowerShell script instead of rewriting registry and firewall commands.

## Workflow

Set `$SkillDir` to this skill folder first. Typical locations:

```powershell
$SkillDir = "$env:USERPROFILE\.claude\skills\sogou-offline"
# or wherever this repository was cloned
```

1. Inspect first:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action status
   ```
2. Apply normal firewall blocking:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action firewall
   ```
3. If Sogou still works online through `127.0.0.1:7890` or another localhost proxy, apply hardening from an elevated PowerShell:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action harden
   ```
4. If blocking causes a focus popup or flashing console window, replace the blocker with a no-window `wscript.exe` blocker:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action fix-flash
   ```
5. If basic typing breaks, restore only the basic Sogou service while keeping network components blocked:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action restore-service
   ```
6. If the user wants to undo everything created by this skill, run:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\sogou-offline.ps1" -Action revert
   ```

## Elevation

Firewall, IFEO registry, service, and scheduled-task changes normally require Administrator rights. If a direct run returns access denied, launch it elevated:

```powershell
Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File', "$SkillDir\scripts\sogou-offline.ps1", '-Action', 'harden')
```

Use the requested action in place of `harden`.

## Important Details

- Windows Firewall program rules may not stop local loopback traffic to `127.0.0.1`, so Sogou can still reach the internet through a local proxy such as port `7890`.
- The `harden` action uses IFEO `Debugger` entries to stop Sogou cloud/web/assistant/update components from launching. It intentionally does not block `SogouImeBroker.exe`.
- Avoid using `cmd.exe /c exit` as the IFEO debugger because it can create focus-stealing console flashes. Use the script's `fix-flash` action to set a silent `wscript.exe //B` blocker.
- Do not disable unrelated proxy, browser, chat, or system firewall rules unless the user explicitly asks.
- Keep logs in `%USERPROFILE%\SogouOfflineSkill.log`.
