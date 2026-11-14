& {
    $ErrorActionPreference = 'Stop'
    try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue } catch {}
    try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    function Resolve-ZhText {
        param([string]$Text)
        return [regex]::Unescape($Text)
    }

    $TagInfo = Resolve-ZhText '[\u4fe1\u606f]'
    $TagOk   = Resolve-ZhText '[\u6210\u529f]'

    $UpdateEngine = ($env:AGY_ZH_UPDATE_ENGINE -eq '1')
    $NoShortcut   = ($env:AGY_ZH_NO_SHORTCUT -eq '1')

    $RepoRawBase = if ($env:AGY_ZH_REPO_RAW) { $env:AGY_ZH_REPO_RAW } else { 'https://raw.githubusercontent.com/guuguo/antigravity-zh-launcher/main' }
    $HansReleaseBase = 'https://github.com/yuexps/Antigravity-Hans/releases/latest/download'
    $PluginName = 'antigravity-zh-prompt'

    $InstallRoot = Join-Path $env:LOCALAPPDATA 'antigravity-zh-launcher'
    $BinDir      = Join-Path $InstallRoot 'bin'
    $HansExe     = Join-Path $BinDir 'antigravity-hans.exe'
    $AgyZhPs1    = Join-Path $BinDir 'agy-zh.ps1'
    $AgyZhCmd    = Join-Path $BinDir 'agy-zh.cmd'
    $PsExe       = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

    $ConfigDir = if ($env:GEMINI_CONFIG_DIR) { $env:GEMINI_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.gemini\config' }
    $PluginDir = Join-Path $ConfigDir "plugins\$PluginName"

    New-Item -ItemType Directory -Force -Path $BinDir, (Join-Path $PluginDir 'assets'), (Join-Path $PluginDir 'rules') | Out-Null

    # 1. Deploy antigravity-zh-prompt plugin (local repo if present, otherwise fetch from GitHub)
    $LocalRepoRoot = if ($PSScriptRoot) { $PSScriptRoot } else { '' }
    $IsLocalRepo = ($LocalRepoRoot -ne '') -and (Test-Path (Join-Path $LocalRepoRoot "plugins\$PluginName\plugin.json"))

    if ($IsLocalRepo) {
        Write-Host "$TagInfo $(Resolve-ZhText '\u4f7f\u7528\u672c\u5730\u4ed3\u5e93\u6e90\u6587\u4ef6\u5b89\u88c5\u63d0\u793a\u8bcd\u63d2\u4ef6:') $LocalRepoRoot"
        Copy-Item -Force (Join-Path $LocalRepoRoot "plugins\$PluginName\plugin.json") (Join-Path $PluginDir 'plugin.json')
        Copy-Item -Force (Join-Path $LocalRepoRoot "plugins\$PluginName\assets\logo.svg") (Join-Path $PluginDir 'assets\logo.svg')
        Copy-Item -Force (Join-Path $LocalRepoRoot "plugins\$PluginName\rules\AGENTS.md") (Join-Path $PluginDir 'rules\AGENTS.md')
    } else {
        Write-Host "$TagInfo $(Resolve-ZhText '\u6b63\u5728\u4ece GitHub \u4e0b\u8f7d\u5168\u6d41\u7a0b\u4e2d\u6587\u601d\u8003\u63d0\u793a\u8bcd\u63d2\u4ef6...')"
        Invoke-WebRequest -UseBasicParsing -Uri "$RepoRawBase/plugins/$PluginName/plugin.json" -OutFile (Join-Path $PluginDir 'plugin.json')
        Invoke-WebRequest -UseBasicParsing -Uri "$RepoRawBase/plugins/$PluginName/assets/logo.svg" -OutFile (Join-Path $PluginDir 'assets\logo.svg')
        Invoke-WebRequest -UseBasicParsing -Uri "$RepoRawBase/plugins/$PluginName/rules/AGENTS.md" -OutFile (Join-Path $PluginDir 'rules\AGENTS.md')
    }

    # 2. Download & SHA-256 verify antigravity-hans.exe
    if (-not $UpdateEngine -and (Test-Path $HansExe)) {
        Write-Host "$TagInfo $(Resolve-ZhText '\u68c0\u6d4b\u5230\u5df2\u5b89\u88c5\u7684\u6c49\u5316\u5f15\u64ce\uff0c\u76f4\u63a5\u590d\u7528:') $HansExe"
    } else {
        $TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ('agy-zh-' + [System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null
        try {
            $AssetName = 'antigravity-hans-windows-amd64.exe'
            $TmpExe = Join-Path $TmpDir $AssetName
            $TmpSums = Join-Path $TmpDir 'SHA256SUMS'

            Write-Host "$TagInfo $(Resolve-ZhText '\u6b63\u5728\u4e0b\u8f7d\u6c49\u5316\u5f15\u64ce\u5e76\u9a8c\u8bc1 SHA-256:') $AssetName"
            Invoke-WebRequest -UseBasicParsing -Uri "$HansReleaseBase/$AssetName" -OutFile $TmpExe
            Invoke-WebRequest -UseBasicParsing -Uri "$HansReleaseBase/SHA256SUMS" -OutFile $TmpSums

            $MatchedLine = Get-Content -Path $TmpSums | Where-Object { $_ -match "\s+$([regex]::Escape($AssetName))$" } | Select-Object -First 1
            if (-not $MatchedLine) {
                throw (Resolve-ZhText '\u5728\u5b98\u65b9 SHA256SUMS \u4e2d\u672a\u627e\u5230\u5bf9\u5e94\u6821\u9a8c\u548c\u3002')
            }
            $ExpectedHash = ($MatchedLine.Trim() -split '\s+')[0].ToLowerInvariant()
            $ActualHash = (Get-FileHash -Algorithm SHA256 -Path $TmpExe).Hash.ToLowerInvariant()
            if ($ActualHash -ne $ExpectedHash) {
                throw "$(Resolve-ZhText 'SHA-256 \u6821\u9a8c\u5931\u8d25\uff01') expected=$ExpectedHash actual=$ActualHash"
            }

            Move-Item -Force $TmpExe $HansExe
            Write-Host "$TagOk $(Resolve-ZhText '\u6c49\u5316\u5f15\u64ce\u5df2\u5b89\u88c5\u5e76\u901a\u8fc7 SHA-256 \u6821\u9a8c:') $HansExe"
        } finally {
            if (Test-Path $TmpDir) {
                Remove-Item -Recurse -Force $TmpDir
            }
        }
    }

    # 3. Write pure-ASCII orchestrator agy-zh.ps1 and agy-zh.cmd
    $AgyZhScript = @'
param(
    [Parameter(Position = 0)]
    [string]$SubCommand = 'start',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RestArgs
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

function Resolve-ZhText {
    param([string]$Text)
    return [regex]::Unescape($Text)
}

$TagOk = Resolve-ZhText '[\u6210\u529f]'
$ShortcutName = Resolve-ZhText 'Antigravity \u4e2d\u6587.lnk'
$PluginName = 'antigravity-zh-prompt'
$ConfigDir = if ($env:GEMINI_CONFIG_DIR) { $env:GEMINI_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.gemini\config' }
$ConfigFile = Join-Path $ConfigDir 'config.json'
$PluginDir = Join-Path $ConfigDir "plugins\$PluginName"
$HansExe = if ($env:AGY_HANS_BIN) { $env:AGY_HANS_BIN } else { Join-Path $PSScriptRoot 'antigravity-hans.exe' }

function Set-ZhPluginEnabled {
    param([bool]$Enabled)
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
    $data = [PSCustomObject]@{}
    if (Test-Path $ConfigFile) {
        $raw = Get-Content -Raw -Encoding UTF8 -Path $ConfigFile
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            $parsed = $raw | ConvertFrom-Json
            if ($null -ne $parsed) { $data = $parsed }
        }
    }
    if (-not ($data.PSObject.Properties.Name -contains 'plugins') -or $null -eq $data.plugins) {
        $data | Add-Member -NotePropertyName 'plugins' -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    $entry = $null
    if ($data.plugins.PSObject.Properties.Name -contains $PluginName) {
        $entry = $data.plugins.$PluginName
    }
    if ($null -eq $entry) {
        $entry = [PSCustomObject]@{}
        $data.plugins | Add-Member -NotePropertyName $PluginName -NotePropertyValue $entry -Force
    }
    $entry | Add-Member -NotePropertyName 'enabled' -NotePropertyValue $Enabled -Force

    $json = ($data | ConvertTo-Json -Depth 20) + "`n"
    $tmpPath = Join-Path $ConfigDir ('.config.' + [System.Guid]::NewGuid().ToString('N') + '.tmp')
    [System.IO.File]::WriteAllText($tmpPath, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -Force $tmpPath $ConfigFile
}

function Get-ZhPluginEnabled {
    if (Test-Path $ConfigFile) {
        try {
            $data = Get-Content -Raw -Encoding UTF8 -Path $ConfigFile | ConvertFrom-Json
            if ($null -ne $data.plugins -and ($data.plugins.PSObject.Properties.Name -contains $PluginName)) {
                $val = $data.plugins.$PluginName.enabled
                if ($val -is [bool]) { return $val }
            }
        } catch {}
    }
    $pluginJson = Join-Path $PluginDir 'plugin.json'
    if (Test-Path $pluginJson) {
        try {
            $pdata = Get-Content -Raw -Encoding UTF8 -Path $pluginJson | ConvertFrom-Json
            if ($pdata.disabled -eq $true) { return $false }
            return $true
        } catch {}
    }
    return $false
}

function Test-ActiveHansMonitor {
    $procs = Get-CimInstance Win32_Process -Filter "Name = 'antigravity-hans.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match '--app' }
    return ($null -ne $procs -and @($procs).Count -gt 0)
}

function Find-OriginalExe {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'),
        (Join-Path ${env:ProgramFiles} 'Antigravity\Antigravity.exe'),
        (Join-Path ${env:ProgramFiles} 'Google Antigravity\Antigravity.exe')
    )
    foreach ($p in $candidates) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    return $null
}

function New-ZhShortcut {
    $targets = @(
        ([Environment]::GetFolderPath('Desktop')),
        ([Environment]::GetFolderPath('Programs'))
    )
    $wsh = New-Object -ComObject WScript.Shell
    $selfScript = Join-Path $PSScriptRoot 'agy-zh.ps1'
    $origExe = Find-OriginalExe
    $desc = Resolve-ZhText '\u4ee5\u4e2d\u6587\u754c\u9762\u4e0e\u5168\u6d41\u7a0b\u4e2d\u6587\u601d\u8003\u63d0\u793a\u8bcd\u542f\u52a8 Antigravity'
    $psExePath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

    foreach ($dir in $targets) {
        if ([string]::IsNullOrWhiteSpace($dir)) { continue }
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $lnkPath = Join-Path $dir $ShortcutName
        $sc = $wsh.CreateShortcut($lnkPath)
        $sc.TargetPath = $psExePath
        $sc.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$selfScript`" start --nogui"
        $sc.WorkingDirectory = $PSScriptRoot
        if ($origExe) {
            $sc.IconLocation = "$origExe,0"
        }
        $sc.Description = $desc
        $sc.Save()
        Write-Host "$TagOk $(Resolve-ZhText '\u5df2\u521b\u5efa\u300cAntigravity \u4e2d\u6587\u300d\u5feb\u6377\u65b9\u5f0f:') $lnkPath"
    }
}

switch ($SubCommand.ToLowerInvariant()) {
    'start' {
        if (-not (Test-Path $HansExe)) {
            throw "$(Resolve-ZhText '\u672a\u627e\u5230 antigravity-hans.exe\uff0c\u8bf7\u91cd\u65b0\u8fd0\u884c install.ps1\u3002') ($HansExe)"
        }
        if (Test-Path (Join-Path $PluginDir 'plugin.json')) {
            Set-ZhPluginEnabled -Enabled $true
        }
        $argsList = @('--app')
        if ($RestArgs -contains '--nogui') {
            $argsList += '--nogui'
        }
        try {
            $proc = Start-Process -FilePath $HansExe -ArgumentList $argsList -NoNewWindow -PassThru
            $proc.WaitForExit()
        } finally {
            Start-Sleep -Milliseconds 300
            if (-not (Test-ActiveHansMonitor)) {
                Set-ZhPluginEnabled -Enabled $false
            }
        }
    }
    'stop' {
        if (Test-Path $HansExe) {
            & $HansExe --stop --app 2>$null | Out-Null
        }
        Set-ZhPluginEnabled -Enabled $false
        Write-Host "$TagOk $(Resolve-ZhText '\u5df2\u505c\u6b62\u4e2d\u6587\u6c49\u5316\u76d1\u89c6\u5668\uff0c\u5e76\u5173\u95ed\u4e2d\u6587\u601d\u8003\u63d0\u793a\u8bcd\u63d2\u4ef6\u3002')"
    }
    'prompt' {
        $act = if ($RestArgs.Count -gt 0) { $RestArgs[0].ToLowerInvariant() } else { 'status' }
        switch ($act) {
            'on' {
                Set-ZhPluginEnabled -Enabled $true
                Write-Host "$TagOk $(Resolve-ZhText '\u5df2\u5f00\u542f\u4e2d\u6587\u601d\u8003\u63d0\u793a\u8bcd\u63d2\u4ef6 (antigravity-zh-prompt)\u3002')"
            }
            'off' {
                Set-ZhPluginEnabled -Enabled $false
                Write-Host "$TagOk $(Resolve-ZhText '\u5df2\u5173\u95ed\u4e2d\u6587\u601d\u8003\u63d0\u793a\u8bcd\u63d2\u4ef6 (antigravity-zh-prompt)\u3002')"
            }
            'status' {
                $st = Get-ZhPluginEnabled
                if ($st) {
                    Write-Host (Resolve-ZhText '\u63d0\u793a\u8bcd\u63d2\u4ef6 (antigravity-zh-prompt): \u5df2\u5f00\u542f (enabled: true)')
                } else {
                    Write-Host (Resolve-ZhText '\u63d0\u793a\u8bcd\u63d2\u4ef6 (antigravity-zh-prompt): \u5df2\u5173\u95ed (enabled: false)')
                }
            }
            default {
                throw (Resolve-ZhText '\u7528\u6cd5: agy-zh prompt <on|off|status>')
            }
        }
    }
    'shortcut' {
        New-ZhShortcut
    }
    'status' {
        $orig = Find-OriginalExe
        $st = Get-ZhPluginEnabled
        $active = Test-ActiveHansMonitor
        $desktopLnk = Join-Path ([Environment]::GetFolderPath('Desktop')) $ShortcutName
        $programsLnk = Join-Path ([Environment]::GetFolderPath('Programs')) $ShortcutName
        $lnkList = @()
        if (Test-Path $desktopLnk) { $lnkList += $desktopLnk }
        if (Test-Path $programsLnk) { $lnkList += $programsLnk }

        Write-Host (Resolve-ZhText '=== Antigravity \u53cc\u5165\u53e3\u6c49\u5316\u72b6\u6001 ===')
        Write-Host "$(Resolve-ZhText '\u539f\u7248\u5165\u53e3 (\u7eaf\u51c0\u82f1\u6587): ') $(if ($orig) { $orig } else { Resolve-ZhText '\u672a\u68c0\u6d4b\u5230 Antigravity.exe' })"
        Write-Host "$(Resolve-ZhText '\u4e2d\u6587\u5165\u53e3 (\u53cc\u6548\u8054\u52a8): ') $(if ($lnkList.Count -gt 0) { $lnkList -join '; ' } else { Resolve-ZhText '\u672a\u521b\u5efa\uff08\u53ef\u8fd0\u884c agy-zh shortcut \u751f\u6210\uff09' })"
        Write-Host "$(Resolve-ZhText '\u52a8\u6001\u6c49\u5316\u5f15\u64ce (CDP) : ') $(if (Test-Path $HansExe) { $HansExe } else { Resolve-ZhText '\u672a\u5b89\u88c5' })"
        Write-Host "$(Resolve-ZhText '\u4e2d\u6587\u601d\u8003\u63d0\u793a\u8bcd\u63d2\u4ef6 : ') $(if (Test-Path (Join-Path $PluginDir 'plugin.json')) { "$(Resolve-ZhText '\u5df2\u5b89\u88c5 ')($PluginDir)" } else { Resolve-ZhText '\u672a\u5b89\u88c5' })"
        Write-Host "$(Resolve-ZhText '\u63d0\u793a\u8bcd\u5f53\u524d\u5f00\u5173\u72b6\u6001 : ') $(if ($st) { Resolve-ZhText '\u5df2\u5f00\u542f (enabled: true)' } else { Resolve-ZhText '\u5df2\u5173\u95ed (enabled: false\uff0c\u539f\u7248\u5165\u53e3\u7eaf\u51c0)' })"
        Write-Host "$(Resolve-ZhText '\u540e\u53f0\u6c49\u5316\u76d1\u89c6\u5668\u8fdb\u7a0b : ') $(if ($active) { Resolve-ZhText '\u8fd0\u884c\u4e2d' } else { Resolve-ZhText '\u672a\u8fd0\u884c' })"
    }
    default {
        Write-Host (Resolve-ZhText 'agy-zh - Antigravity \u53cc\u5165\u53e3\u65e0\u635f\u6c49\u5316\u4e0e\u4e2d\u6587\u601d\u8003\u63d0\u793a\u8bcd\u8054\u52a8\u542f\u52a8\u5668 (Windows)')
        Write-Host (Resolve-ZhText '\u7528\u6cd5: agy-zh <start|stop|status|prompt <on|off|status>|shortcut>')
    }
}
'@

    [System.IO.File]::WriteAllText($AgyZhPs1, $AgyZhScript + "`r`n", [System.Text.UTF8Encoding]::new($false))
    $CmdContent = "@echo off`r`n`"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`" -NoProfile -ExecutionPolicy Bypass -File `"%~dp0agy-zh.ps1`" %*`r`n"
    [System.IO.File]::WriteAllText($AgyZhCmd, $CmdContent, [System.Text.UTF8Encoding]::new($false))

    # 4. Add BinDir to User Path if missing
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $segments = @()
    if ($userPath) {
        $segments = @($userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    $normalizedBin = $BinDir.TrimEnd('\')
    $hasBin = $false
    foreach ($seg in $segments) {
        if ($seg.Trim().TrimEnd('\').Equals($normalizedBin, [System.StringComparison]::OrdinalIgnoreCase)) {
            $hasBin = $true
            break
        }
    }
    if (-not $hasBin) {
        $newUserPath = (($segments + $BinDir) -join ';')
        [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
        if ($env:Path) { $env:Path = "$env:Path;$BinDir" } else { $env:Path = $BinDir }
        Write-Host "$TagOk $(Resolve-ZhText '\u5df2\u5c06\u547d\u4ee4\u884c\u76ee\u5f55\u52a0\u5165\u7528\u6237 Path:') $BinDir"
    }

    # 5. Keep plugin disabled by default (stock entry stays clean)
    & $PsExe -NoProfile -ExecutionPolicy Bypass -File $AgyZhPs1 prompt off | Out-Null

    if (-not $NoShortcut) {
        & $PsExe -NoProfile -ExecutionPolicy Bypass -File $AgyZhPs1 shortcut
    }

    Write-Host ''
    Write-Host (Resolve-ZhText '\u5b89\u88c5\u5b8c\u6210\uff01')
    Write-Host (Resolve-ZhText '  \u2022 \u539f\u59cb\u82f1\u6587\u5165\u53e3\uff1a\u7167\u5e38\u6253\u5f00\u539f\u7248 Antigravity\uff08\u4fdd\u6301\u539f\u5382\u82f1\u6587 UI \u4e0e\u539f\u59cb\u63d0\u793a\u8bcd\uff09')
    Write-Host (Resolve-ZhText '  \u2022 \u72ec\u7acb\u4e2d\u6587\u5165\u53e3\uff1a\u53cc\u51fb\u684c\u9762\u6216\u5f00\u59cb\u83dc\u5355\u4e2d\u7684\u300cAntigravity \u4e2d\u6587\u300d\u5feb\u6377\u65b9\u5f0f')
    Write-Host "  $(Resolve-ZhText '\u2022 \u547d\u4ee4\u884c\u7ba1\u7406  \uff1a\u5728\u7ec8\u7aef\u8fd0\u884c agy-zh status \u6216\u4f7f\u7528:') $AgyZhCmd"
}
