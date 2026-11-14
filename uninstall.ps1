param(
    [switch]$Purge
)

$ErrorActionPreference = 'Stop'

$PluginName = 'antigravity-zh-prompt'
$InstallRoot = Join-Path $env:LOCALAPPDATA 'antigravity-zh-launcher'
$BinDir = Join-Path $InstallRoot 'bin'
$HansExe = Join-Path $BinDir 'antigravity-hans.exe'
$AgyZhPs1 = Join-Path $BinDir 'agy-zh.ps1'

$ConfigDir = if ($env:GEMINI_CONFIG_DIR) { $env:GEMINI_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.gemini\config' }
$ConfigFile = Join-Path $ConfigDir 'config.json'
$PluginDir = Join-Path $ConfigDir "plugins\$PluginName"

if (Test-Path $AgyZhPs1) {
    try { & $AgyZhPs1 stop | Out-Null } catch {}
} elseif (Test-Path $HansExe) {
    try { & $HansExe --stop --app 2>$null | Out-Null } catch {}
}

if (Test-Path $ConfigFile) {
    try {
        $raw = Get-Content -Raw -Encoding UTF8 -Path $ConfigFile
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            $data = $raw | ConvertFrom-Json
            if ($null -ne $data -and ($data.PSObject.Properties.Name -contains 'plugins') -and $null -ne $data.plugins) {
                if ($data.plugins.PSObject.Properties.Name -contains $PluginName) {
                    $data.plugins.PSObject.Properties.Remove($PluginName)
                    $json = ($data | ConvertTo-Json -Depth 20) + "`n"
                    $tmpPath = Join-Path $ConfigDir ('.config.' + [System.Guid]::NewGuid().ToString('N') + '.tmp')
                    [System.IO.File]::WriteAllText($tmpPath, $json, [System.Text.UTF8Encoding]::new($false))
                    Move-Item -Force $tmpPath $ConfigFile
                    Write-Host "[成功] 已从 $ConfigFile 移除 $PluginName 记录。"
                }
            }
        }
    } catch {}
}

if (Test-Path $PluginDir) {
    Remove-Item -Recurse -Force $PluginDir
    Write-Host "[成功] 已删除插件目录: $PluginDir"
}

$lnkPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Antigravity 中文.lnk'
if (Test-Path $lnkPath) {
    Remove-Item -Force $lnkPath
    Write-Host "[成功] 已删除桌面快捷方式: $lnkPath"
}

if ($Purge) {
    if (Test-Path $InstallRoot) {
        Remove-Item -Recurse -Force $InstallRoot
        Write-Host "[成功] 已彻底删除安装目录与汉化引擎: $InstallRoot"
    }
} else {
    foreach ($f in @($AgyZhPs1, (Join-Path $BinDir 'agy-zh.cmd'))) {
        if (Test-Path $f) {
            Remove-Item -Force $f
            Write-Host "[成功] 已删除: $f"
        }
    }
    Write-Host "[提示] 已保留底层引擎 ($HansExe)；如需一并清理请传入 -Purge。"
}

Write-Host ''
Write-Host '卸载完成。原版 Antigravity 保持完整无损。'
