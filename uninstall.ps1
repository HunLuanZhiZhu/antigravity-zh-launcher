& {
    $ErrorActionPreference = 'Stop'
    try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue } catch {}
    try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

    function Resolve-ZhText {
        param([string]$Text)
        return [regex]::Unescape($Text)
    }

    $TagOk   = Resolve-ZhText '[\u6210\u529f]'
    $TagWarn = Resolve-ZhText '[\u63d0\u793a]'
    $Purge   = ($env:AGY_ZH_PURGE -eq '1')

    $PluginName   = 'antigravity-zh-prompt'
    $ShortcutName = Resolve-ZhText 'Antigravity \u4e2d\u6587.lnk'
    $InstallRoot  = Join-Path $env:LOCALAPPDATA 'antigravity-zh-launcher'
    $BinDir       = Join-Path $InstallRoot 'bin'
    $HansExe      = Join-Path $BinDir 'antigravity-hans.exe'
    $BaseOverlay  = Join-Path $BinDir 'antigravity-hans-overlay.base.js'
    $AgyZhPs1     = Join-Path $BinDir 'agy-zh.ps1'
    $PsExe        = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

    $ConfigDir  = if ($env:GEMINI_CONFIG_DIR) { $env:GEMINI_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.gemini\config' }
    $ConfigFile = Join-Path $ConfigDir 'config.json'
    $PluginDir  = Join-Path $ConfigDir "plugins\$PluginName"

    if (Test-Path $AgyZhPs1) {
        try { & $PsExe -NoProfile -ExecutionPolicy Bypass -File $AgyZhPs1 stop | Out-Null } catch {}
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
                        Write-Host "$TagOk $(Resolve-ZhText '\u5df2\u4ece config.json \u79fb\u9664 antigravity-zh-prompt \u8bb0\u5f55:') $ConfigFile"
                    }
                }
            }
        } catch {}
    }

    if (Test-Path $PluginDir) {
        Remove-Item -Recurse -Force $PluginDir
        Write-Host "$TagOk $(Resolve-ZhText '\u5df2\u5220\u9664\u63d2\u4ef6\u76ee\u5f55:') $PluginDir"
    }

    foreach ($dir in @(([Environment]::GetFolderPath('Desktop')), ([Environment]::GetFolderPath('Programs')))) {
        if ([string]::IsNullOrWhiteSpace($dir)) { continue }
        $lnkPath = Join-Path $dir $ShortcutName
        if (Test-Path $lnkPath) {
            Remove-Item -Force $lnkPath
            Write-Host "$TagOk $(Resolve-ZhText '\u5df2\u5220\u9664\u5feb\u6377\u65b9\u5f0f:') $lnkPath"
        }
    }

    # Remove BinDir from User Path
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath) {
        $normalizedBin = $BinDir.TrimEnd('\')
        $kept = @()
        $removed = $false
        foreach ($seg in ($userPath -split ';')) {
            if ([string]::IsNullOrWhiteSpace($seg)) { continue }
            if ($seg.Trim().TrimEnd('\').Equals($normalizedBin, [System.StringComparison]::OrdinalIgnoreCase)) {
                $removed = $true
            } else {
                $kept += $seg
            }
        }
        if ($removed) {
            [Environment]::SetEnvironmentVariable('Path', ($kept -join ';'), 'User')
            Write-Host "$TagOk $(Resolve-ZhText '\u5df2\u4ece\u7528\u6237 Path \u79fb\u9664\u547d\u4ee4\u884c\u76ee\u5f55:') $BinDir"
        }
    }

    if ($Purge) {
        if (Test-Path $InstallRoot) {
            Remove-Item -Recurse -Force $InstallRoot
            Write-Host "$TagOk $(Resolve-ZhText '\u5df2\u5f7b\u5e95\u5220\u9664\u5b89\u88c5\u76ee\u5f55\u4e0e\u8bcd\u5e93\u7f13\u5b58:') $InstallRoot"
        }
    } else {
        foreach ($f in @($AgyZhPs1, (Join-Path $BinDir 'agy-zh.cmd'), (Join-Path $BinDir 'agy-zh-launch.vbs'), (Join-Path $BinDir 'antigravity-hans-overlay.js'), $HansExe)) {
            if (Test-Path $f) {
                Remove-Item -Force $f
                Write-Host "$TagOk $(Resolve-ZhText '\u5df2\u5220\u9664\u6587\u4ef6:') $f"
            }
        }
        $logsDir = Join-Path $InstallRoot 'logs'
        if (Test-Path $logsDir) {
            Remove-Item -Recurse -Force $logsDir
        }
        if (Test-Path $BaseOverlay) {
            Write-Host "$TagWarn $(Resolve-ZhText '\u5df2\u4fdd\u7559\u7eaf\u6587\u672c\u57fa\u7840\u8bcd\u5e93\u7f13\u5b58\uff08\u5982\u9700\u4e00\u5e76\u6e05\u7406\u8bf7\u8bbe\u7f6e $env:AGY_ZH_PURGE=''1'' \u540e\u91cd\u8dd1\u5378\u8f7d\uff09:') $BaseOverlay"
        }
    }

    Write-Host ''
    Write-Host (Resolve-ZhText '\u5378\u8f7d\u5b8c\u6210\u3002\u539f\u7248 Antigravity \u4fdd\u6301\u5b8c\u6574\u65e0\u635f\u3002')
}
