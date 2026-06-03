param(
    [ValidateSet('status','firewall','harden','fix-flash','restore-service','revert')]
    [string]$Action = 'status',
    [int[]]$LocalProxyPorts = @(7890)
)

$ErrorActionPreference = 'Continue'
$Log = Join-Path $env:USERPROFILE 'SogouOfflineSkill.log'
$RuleGroup = 'Block Sogou Input Network - Skill'
$RuleNamePrefix = 'Block Sogou Outbound -'
$IfeoRoot = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
$SilentBlocker = Join-Path $env:USERPROFILE 'SogouSilentBlocker.vbs'

$InstallDirs = @(
    'C:\Program Files (x86)\SogouInput',
    'C:\Windows\SysWOW64\IME\SogouPY',
    'C:\Windows\System32\IME\SogouPY',
    (Join-Path $env:APPDATA 'sogou_voice_assistant_pc'),
    (Join-Path $env:LOCALAPPDATA 'sogoupdf')
) | Where-Object { Test-Path -LiteralPath $_ }

$BlockedExeNames = @(
    'SogouCloud.exe',
    'SGWebRender.exe',
    'SGMyInput.exe',
    'SGTool.exe',
    'SGDownload.exe',
    'PinyinUp.exe',
    'userNetSchedule.exe',
    'SogouComMgr.exe',
    'SogouSvc.exe',
    'SogouExe.exe',
    'SOGOUSmartAssistant.exe',
    'SGSmartAssistant.exe',
    'sogou_voice_assistant.exe',
    'SGBizLauncher.exe',
    'SGWizard.exe',
    'SGIGuideHelper.exe',
    'SogouToolkits.exe',
    'SogouImeRepair.exe',
    'SGWangzai.exe',
    'SogouPlayLauncher.exe',
    'SogouFlash.exe',
    'SGRender.exe',
    'biz_helper.exe',
    'biz_notify.exe',
    'biz_render.exe',
    'ginkgo.exe',
    'launcher_server.exe',
    'isgpet.exe',
    'systembeautify.exe'
) | Sort-Object -Unique

function Write-Log {
    param([string]$Message)
    "[$(Get-Date -Format s)] $Message" | Tee-Object -FilePath $Log -Append
}

function Get-SogouExecutables {
    $items = foreach ($dir in $InstallDirs) {
        Get-ChildItem -LiteralPath $dir -Recurse -Filter *.exe -ErrorAction SilentlyContinue
    }
    $items | Sort-Object FullName -Unique
}

function Get-SogouProcesses {
    Get-CimInstance Win32_Process |
        Where-Object {
            $_.Name -match 'sogou|sogo|^SG' -or
            $_.ExecutablePath -match 'sogou|sogo' -or
            $_.CommandLine -match 'sogou|sogo'
        }
}

function Show-Status {
    $proc = Get-CimInstance Win32_Process | Select-Object ProcessId,Name,ExecutablePath,CommandLine
    $portPattern = ($LocalProxyPorts | ForEach-Object { "127\.0\.0\.1:$($_)|::1:$($_)" }) -join '|'
    $allConnections = Get-NetTCPConnection -ErrorAction SilentlyContinue |
        Where-Object { $_.State -in 'Established','SynSent','Listen' } |
        ForEach-Object {
            $c = $_
            $p = $proc | Where-Object ProcessId -eq $c.OwningProcess
            [pscustomobject]@{
                Local = "$($c.LocalAddress):$($c.LocalPort)"
                Remote = "$($c.RemoteAddress):$($c.RemotePort)"
                State = $c.State
                PID = $c.OwningProcess
                Name = $p.Name
                Path = $p.ExecutablePath
            }
        }
    $sogouConnections = $allConnections |
        Where-Object { $_.Name -match 'sogou|sogo|^SG' -or $_.Path -match 'sogou|sogo' }
    $proxyConnections = $allConnections |
        Where-Object { $portPattern -and $_.Remote -match $portPattern }

    [pscustomobject]@{
        SogouDirectories = ($InstallDirs -join '; ')
        ExecutablesFound = (Get-SogouExecutables | Measure-Object).Count
        FirewallRules = (Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.Group -eq $RuleGroup -or $_.DisplayName -like "$RuleNamePrefix*" } | Measure-Object).Count
        IfeoBlocks = ($BlockedExeNames | Where-Object { Test-Path -LiteralPath (Join-Path $IfeoRoot $_) } | Measure-Object).Count
        SogouProcesses = (Get-SogouProcesses | Measure-Object).Count
        SogouConnections = ($sogouConnections | Measure-Object).Count
        LocalProxyConnections = ($proxyConnections | Measure-Object).Count
    } | Format-List

    if ($sogouConnections) {
        'Sogou connections:' | Write-Output
        $sogouConnections | Format-Table -AutoSize
    }
    if ($proxyConnections) {
        'Local proxy connections:' | Write-Output
        $proxyConnections | Format-Table -AutoSize
    }
}

function Set-Firewall {
    $created = 0
    $skipped = 0
    foreach ($exe in Get-SogouExecutables) {
        $path = $exe.FullName
        $leaf = [System.IO.Path]::GetFileNameWithoutExtension($path)
        $hash = [Math]::Abs($path.GetHashCode()).ToString('x')
        $name = "$RuleNamePrefix$leaf - $hash"
        $existing = Get-NetFirewallApplicationFilter -Program $path -ErrorAction SilentlyContinue |
            ForEach-Object { Get-NetFirewallRule -AssociatedNetFirewallApplicationFilter $_ -ErrorAction SilentlyContinue } |
            Where-Object { ($_.Group -eq $RuleGroup -or $_.DisplayName -like "$RuleNamePrefix*") -and $_.Direction -eq 'Outbound' -and $_.Action -eq 'Block' }
        if ($existing) {
            $skipped++
            continue
        }
        New-NetFirewallRule -DisplayName $name -Group $RuleGroup -Direction Outbound -Action Block -Program $path -Profile Any -Enabled True | Out-Null
        $created++
    }

    Get-NetFirewallRule -ErrorAction SilentlyContinue |
        Where-Object {
            ($_.DisplayName -match 'Sogou|搜狗' -or $_.Group -match 'Sogou|搜狗') -and
            $_.Direction -eq 'Inbound' -and
            $_.Action -eq 'Allow'
        } |
        Disable-NetFirewallRule -ErrorAction SilentlyContinue

    Write-Log "Firewall complete. Created=$created Skipped=$skipped Group=$RuleGroup"
}

function Set-IfeoBlocks {
    if (-not (Test-Path -LiteralPath $SilentBlocker)) {
        'WScript.Quit 0' | Out-File -LiteralPath $SilentBlocker -Encoding ASCII
    }
    $debugger = "C:\Windows\System32\wscript.exe //B //Nologo `"$SilentBlocker`""
    $changed = 0
    foreach ($name in $BlockedExeNames) {
        $key = Join-Path $IfeoRoot $name
        if (-not (Test-Path -LiteralPath $key)) {
            New-Item -Path $key -Force | Out-Null
        }
        New-ItemProperty -LiteralPath $key -Name 'Debugger' -Value $debugger -PropertyType String -Force | Out-Null
        $changed++
    }
    Write-Log "IFEO no-window blocks set: $changed"
}

function Stop-SogouNetworkProcesses {
    $pattern = '^(' + (($BlockedExeNames | ForEach-Object { [regex]::Escape([System.IO.Path]::GetFileNameWithoutExtension($_)) }) -join '|') + ')$'
    $killed = 0
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -match $pattern } |
        ForEach-Object {
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
            $killed++
        }
    Write-Log "Stopped Sogou network component processes: $killed"
}

function Disable-SogouServiceAndTasks {
    $services = Get-Service -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'Sogou|SogouSvc|SG' -or $_.DisplayName -match 'Sogou|搜狗' }
    foreach ($svc in $services) {
        Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
        Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
    }
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue |
        Where-Object { $_.TaskName -match 'Sogou|搜狗|SG' -or $_.TaskPath -match 'Sogou|搜狗|SG' }
    foreach ($task in $tasks) {
        Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue | Out-Null
    }
    Write-Log "Disabled services=$($services.Count) tasks=$($tasks.Count)"
}

function Restore-SogouService {
    Get-Service -Name 'SogouSvc' -ErrorAction SilentlyContinue | ForEach-Object {
        Set-Service -Name $_.Name -StartupType Manual -ErrorAction SilentlyContinue
        Start-Service -Name $_.Name -ErrorAction SilentlyContinue
        Write-Log "Restored service: $($_.Name)"
    }
}

function Revert-SogouOffline {
    Get-NetFirewallRule -ErrorAction SilentlyContinue |
        Where-Object { $_.Group -eq $RuleGroup -or $_.DisplayName -like "$RuleNamePrefix*" } |
        Remove-NetFirewallRule -ErrorAction SilentlyContinue
    foreach ($name in $BlockedExeNames) {
        $key = Join-Path $IfeoRoot $name
        if (Test-Path -LiteralPath $key) {
            Remove-ItemProperty -LiteralPath $key -Name 'Debugger' -ErrorAction SilentlyContinue
        }
    }
    Restore-SogouService
    Write-Log 'Reverted firewall group and IFEO debugger values created by this skill.'
}

Write-Log "Action started: $Action"
switch ($Action) {
    'status' { Show-Status }
    'firewall' { Set-Firewall; Show-Status }
    'harden' { Set-Firewall; Set-IfeoBlocks; Stop-SogouNetworkProcesses; Disable-SogouServiceAndTasks; Show-Status }
    'fix-flash' { Set-IfeoBlocks; Show-Status }
    'restore-service' { Restore-SogouService; Show-Status }
    'revert' { Revert-SogouOffline; Show-Status }
}
