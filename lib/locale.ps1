function Build-AgyOverlay {
    param([bool]$Force = $false)
    $localePath = Join-Path $AssetRoot "locales\$Lang.json"
    $localeJson = [System.IO.File]::ReadAllText($localePath, [System.Text.Encoding]::UTF8)
    $locale = $localeJson | ConvertFrom-Json
    if ($Lang -eq 'zh-CN') {
        Ensure-EnhancedOverlay -Force $Force | Out-Null
        $custom = @($locale.phrases.PSObject.Properties | ForEach-Object { ,@($_.Name, $_.Value) })
        $prefix = 'window.__antigravityZhCustom = ' + (ConvertTo-Json -InputObject $custom -Depth 5 -Compress) + ";`n"
        $script = $prefix + [System.IO.File]::ReadAllText($OverlayJs, [System.Text.Encoding]::UTF8)
    } else {
        $template = [System.IO.File]::ReadAllText((Join-Path $AssetRoot 'lib\overlay.js'), [System.Text.Encoding]::UTF8)
        $script = $template.Replace('/*__AGY_LOCALE__*/', $localeJson)
    }
    [System.IO.File]::WriteAllText($OverlayJs, $script, [System.Text.UTF8Encoding]::new($false))
}
