param(
    [switch]$UpdateEngine,
    [switch]$NoShortcut
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoRawBase = if ($env:AGY_ZH_REPO_RAW) { $env:AGY_ZH_REPO_RAW } else { 'https://raw.githubusercontent.com/guuguo/antigravity-zh-launcher/main' }
$HansReleaseBase = 'https://github.com/yuexps/Antigravity-Hans/releases/latest/download'
$PluginName = 'antigravity-zh-prompt'

$InstallRoot = Join-Path $env:LOCALAPPDATA 'antigravity-zh-launcher'
$BinDir = Join-Path $InstallRoot 'bin'
$HansExe = Join-Path $BinDir 'antigravity-hans.exe'
$AgyZhPs1 = Join-Path $BinDir 'agy-zh.ps1'
$AgyZhCmd = Join-Path $BinDir 'agy-zh.cmd'

$ConfigDir = if ($env:GEMINI_CONFIG_DIR) { $env:GEMINI_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.gemini\config' }
$PluginDir = Join-Path $ConfigDir "plugins\$PluginName"

New-Item -ItemType Directory -Force -Path $BinDir, (Join-Path $PluginDir 'assets'), (Join-Path $PluginDir 'rules') | Out-Null

# 1. 部署提示词插件（优先使用本地仓库文件，支持 irm | iex 远程安装）
$LocalRepoRoot = if ($PSScriptRoot) { $PSScriptRoot } else { '' }
$IsLocalRepo = ($LocalRepoRoot -ne '') -and (Test-Path (Join-Path $LocalRepoRoot "plugins\$PluginName\plugin.json"))

if ($IsLocalRepo) {
    Write-Host "[信息] 使用本地仓库源文件安装提示词插件: $LocalRepoRoot"
    Copy-Item -Force (Join-Path $LocalRepoRoot "plugins\$PluginName\plugin.json") (Join-Path $PluginDir 'plugin.json')
    Copy-Item -Force (Join-Path $LocalRepoRoot "plugins\$PluginName\assets\logo.svg") (Join-Path $PluginDir 'assets\logo.svg')
    Copy-Item -Force (Join-Path $LocalRepoRoot "plugins\$PluginName\rules\AGENTS.md") (Join-Path $PluginDir 'rules\AGENTS.md')
} else {
    Write-Host '[信息] 正在从 GitHub 下载全流程中文思考提示词插件...'
    Invoke-WebRequest -UseBasicParsing -Uri "$RepoRawBase/plugins/$PluginName/plugin.json" -OutFile (Join-Path $PluginDir 'plugin.json')
    Invoke-WebRequest -UseBasicParsing -Uri "$RepoRawBase/plugins/$PluginName/assets/logo.svg" -OutFile (Join-Path $PluginDir 'assets\logo.svg')
    Invoke-WebRequest -UseBasicParsing -Uri "$RepoRawBase/plugins/$PluginName/rules/AGENTS.md" -OutFile (Join-Path $PluginDir 'rules\AGENTS.md')
}

# 2. 下载并校验 SHA-256 安装 antigravity-hans.exe
if (-not $UpdateEngine -and (Test-Path $HansExe)) {
    Write-Host "[信息] 检测到已安装的汉化引擎，直接复用: $HansExe"
} else {
    $TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("agy-zh-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null
    try {
        $AssetName = 'antigravity-hans-windows-amd64.exe'
        $TmpExe = Join-Path $TmpDir $AssetName
        $TmpSums = Join-Path $TmpDir 'SHA256SUMS'

        Write-Host "[信息] 正在下载汉化引擎 ($AssetName) 并验证 SHA-256..."
        Invoke-WebRequest -UseBasicParsing -Uri "$HansReleaseBase/$AssetName" -OutFile $TmpExe
        Invoke-WebRequest -UseBasicParsing -Uri "$HansReleaseBase/SHA256SUMS" -OutFile $TmpSums

        $MatchedLine = Get-Content -Path $TmpSums | Where-Object { $_ -match "\s+$([regex]::Escape($AssetName))$" } | Select-Object -First 1
        if (-not $MatchedLine) {
            throw "在官方 SHA256SUMS 中未找到 $AssetName 的校验和。"
        }
        $ExpectedHash = ($MatchedLine.Trim() -split '\s+')[0].ToLowerInvariant()
        $ActualHash = (Get-FileHash -Algorithm SHA256 -Path $TmpExe).Hash.ToLowerInvariant()
        if ($ActualHash -ne $ExpectedHash) {
            throw "SHA-256 校验失败！预期 $ExpectedHash，实际 $ActualHash"
        }

        Move-Item -Force $TmpExe $HansExe
        Write-Host "[成功] 汉化引擎已安装并通过 SHA-256 校验: $HansExe"
    } finally {
        if (Test-Path $TmpDir) {
            Remove-Item -Recurse -Force $TmpDir
        }
    }
}

# 3. 写入 Windows 编排脚本 agy-zh.ps1 与命令行封装 agy-zh.cmd
$AgyZhScript = @'
param(
    [Parameter(Position = 0)]
    [string]$SubCommand = 'start',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RestArgs
)

$ErrorActionPreference = 'Stop'
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
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnkPath = Join-Path $desktop 'Antigravity 中文.lnk'
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($lnkPath)
    $sc.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $selfScript = Join-Path $PSScriptRoot 'agy-zh.ps1'
    $sc.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$selfScript`" start --nogui"
    $sc.WorkingDirectory = $PSScriptRoot
    $origExe = Find-OriginalExe
    if ($origExe) {
        $sc.IconLocation = "$origExe,0"
    }
    $sc.Description = '以中文界面与全流程中文思考提示词启动 Antigravity'
    $sc.Save()
    Write-Host "[成功] 已创建桌面中文快捷方式: $lnkPath"
}

switch ($SubCommand.ToLowerInvariant()) {
    'start' {
        if (-not (Test-Path $HansExe)) {
            throw "未找到 antigravity-hans.exe ($HansExe)，请重新运行 install.ps1。"
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
        Write-Host "[成功] 已停止中文汉化监视器，并关闭 $PluginName 插件。"
    }
    'prompt' {
        $act = if ($RestArgs.Count -gt 0) { $RestArgs[0].ToLowerInvariant() } else { 'status' }
        switch ($act) {
            'on' {
                Set-ZhPluginEnabled -Enabled $true
                Write-Host "[成功] 已开启中文思考提示词插件 ($PluginName)。"
            }
            'off' {
                Set-ZhPluginEnabled -Enabled $false
                Write-Host "[成功] 已关闭中文思考提示词插件 ($PluginName)。"
            }
            'status' {
                $st = Get-ZhPluginEnabled
                Write-Host "提示词插件 ($PluginName): $(if ($st) { '已开启 (enabled: true)' } else { '已关闭 (enabled: false)' })"
            }
            default {
                throw '用法: agy-zh prompt <on|off|status>'
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
        $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Antigravity 中文.lnk'
        Write-Host '=== Antigravity 双入口汉化状态 ==='
        Write-Host "原版入口 (纯净英文): $(if ($orig) { $orig } else { '未检测到 Antigravity.exe' })"
        Write-Host "中文入口 (双效联动): $(if (Test-Path $lnk) { $lnk } else { '未创建' })"
        Write-Host "动态汉化引擎 (CDP) : $(if (Test-Path $HansExe) { $HansExe } else { '未安装' })"
        Write-Host "中文思考提示词插件 : $(if (Test-Path (Join-Path $PluginDir 'plugin.json')) { "已安装 ($PluginDir)" } else { '未安装' })"
        Write-Host "提示词当前开关状态 : $(if ($st) { '已开启 (enabled: true)' } else { '已关闭 (enabled: false，原版入口纯净)' })"
        Write-Host "后台汉化监视器进程 : $(if ($active) { '运行中' } else { '未运行' })"
    }
    default {
        Write-Host 'agy-zh - Antigravity 双入口无损汉化与中文思考提示词联动启动器 (Windows)'
        Write-Host '用法: agy-zh <start|stop|status|prompt <on|off|status>|shortcut>'
    }
}
'@

[System.IO.File]::WriteAllText($AgyZhPs1, $AgyZhScript + "`r`n", [System.Text.UTF8Encoding]::new($false))
$CmdContent = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0agy-zh.ps1`" %*`r`n"
[System.IO.File]::WriteAllText($AgyZhCmd, $CmdContent, [System.Text.UTF8Encoding]::new($false))

# 确保安装后默认关闭插件，保持原版入口纯净
& $AgyZhPs1 prompt off | Out-Null

if (-not $NoShortcut) {
    & $AgyZhPs1 shortcut
}

Write-Host ''
Write-Host '安装完成！'
Write-Host '  • 原始英文入口：正常打开原版 Antigravity（保持原厂英文 UI 与原始提示词）'
Write-Host '  • 独立中文入口：双击桌面「Antigravity 中文」快捷方式'
Write-Host "  • CLI 管理入口：$AgyZhCmd status"
