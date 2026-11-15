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
    $AgyZhVbs    = Join-Path $BinDir 'agy-zh-launch.vbs'
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

    # 3. Write pure-ASCII orchestrator agy-zh.ps1, agy-zh.cmd, and zero-flash agy-zh-launch.vbs
    $LaunchVbsContent = @(
        'Option Explicit',
        'Dim fso, shell, dir, psExe, scriptPath, cmd',
        'Set fso = CreateObject("Scripting.FileSystemObject")',
        'Set shell = CreateObject("WScript.Shell")',
        'dir = fso.GetParentFolderName(WScript.ScriptFullName)',
        'psExe = shell.ExpandEnvironmentStrings("%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")',
        'If Not fso.FileExists(psExe) Then',
        '    psExe = "powershell.exe"',
        'End If',
        'scriptPath = fso.BuildPath(dir, "agy-zh.ps1")',
        'cmd = """" & psExe & """ -NoProfile -NonInteractive -ExecutionPolicy Bypass -File """ & scriptPath & """ start --nogui"',
        'shell.Run cmd, 0, False'
    ) -join "`r`n"
    $LaunchVbsB64 = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($LaunchVbsContent + "`r`n"))

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

$TagOk   = Resolve-ZhText '[\u6210\u529f]'
$TagWarn = Resolve-ZhText '[\u63d0\u793a]'
$OverlayVersion = 'agy-zh-v4'
$ShortcutName = Resolve-ZhText 'Antigravity \u4e2d\u6587.lnk'
$LaunchVbsB64 = '__LAUNCH_VBS_B64__'
$PluginName = 'antigravity-zh-prompt'
$ConfigDir = if ($env:GEMINI_CONFIG_DIR) { $env:GEMINI_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.gemini\config' }
$ConfigFile = Join-Path $ConfigDir 'config.json'
$PluginDir = Join-Path $ConfigDir "plugins\$PluginName"
$HansExe = if ($env:AGY_HANS_BIN) { $env:AGY_HANS_BIN } else { Join-Path $PSScriptRoot 'antigravity-hans.exe' }
$OverlayJs = Join-Path (Split-Path -Parent $HansExe) 'antigravity-hans-overlay.js'

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

function Resolve-OverlayUnicode {
    param([string]$Text)
    return [regex]::Replace($Text, '\\u([0-9a-fA-F]{4})', {
        param($m)
        [char][convert]::ToInt32($m.Groups[1].Value, 16)
    })
}

function Replace-Once {
    param(
        [string]$Text,
        [string]$Target,
        [string]$Replacement,
        [string]$Label
    )
    $idx = $Text.IndexOf($Target, [System.StringComparison]::Ordinal)
    if ($idx -lt 0) {
        throw "Enhanced overlay anchor missing: $Label"
    }
    $second = $Text.IndexOf($Target, $idx + $Target.Length, [System.StringComparison]::Ordinal)
    if ($second -ge 0) {
        throw "Enhanced overlay anchor matched multiple times: $Label"
    }
    return $Text.Substring(0, $idx) + $Replacement + $Text.Substring($idx + $Target.Length)
}

function Ensure-EnhancedOverlay {
    param([bool]$Force = $false)
    if (-not (Test-Path $HansExe)) {
        throw "$(Resolve-ZhText '\u672a\u627e\u5230 antigravity-hans.exe') ($HansExe)"
    }
    $exeHash = (Get-FileHash -Algorithm SHA256 -Path $HansExe).Hash.ToLowerInvariant().Substring(0, 16)
    $headerComment = "// antigravity-zh-launcher overlay: $OverlayVersion; engine_sha256=$exeHash"
    if (-not $Force -and (Test-Path $OverlayJs)) {
        try {
            $firstLine = Get-Content -Path $OverlayJs -TotalCount 1 -Encoding UTF8 -ErrorAction SilentlyContinue
            if ($firstLine -eq $headerComment) { return $true }
        } catch {}
    }

    $rawBytes = [System.IO.File]::ReadAllBytes($HansExe)
    $latin1 = [System.Text.Encoding]::GetEncoding(28591).GetString($rawBytes)
    $startMarker = "(() => {`n  if (typeof window === 'undefined') return;`n  const fingerprint = window.__antigravityZhPatchRequestedFingerprint"
    $startIdx = $latin1.IndexOf($startMarker, [System.StringComparison]::Ordinal)
    if ($startIdx -lt 0) {
        $startMarker = "(() => {`r`n  if (typeof window === 'undefined') return;`r`n  const fingerprint = window.__antigravityZhPatchRequestedFingerprint"
        $startIdx = $latin1.IndexOf($startMarker, [System.StringComparison]::Ordinal)
    }
    if ($startIdx -lt 0) {
        throw 'Failed to locate embedded overlay start in antigravity-hans.exe'
    }
    $endIdx = $latin1.IndexOf('})();', $startIdx + $startMarker.Length, [System.StringComparison]::Ordinal)
    if ($endIdx -lt 0) {
        throw 'Failed to locate embedded overlay end in antigravity-hans.exe'
    }
    $js = [System.Text.Encoding]::UTF8.GetString($rawBytes, $startIdx, ($endIdx + 5 - $startIdx))

    $phrasesAddon = @(
        '  const phrases = new Map([',
        '    ["Ask anything, @ to mention, / for actions", "\u60f3\u95ee\u4ec0\u4e48\u90fd\u53ef\u4ee5\uff0c@ \u5f15\u7528\uff0c/ \u6267\u884c\u52a8\u4f5c"],',
        '    ["Ask anything, @ to mention", "\u60f3\u95ee\u4ec0\u4e48\u90fd\u53ef\u4ee5\uff0c@ \u5f15\u7528"],',
        '    ["Message subagent, @ to mention, / for actions", "\u5411\u5b50\u667a\u80fd\u4f53\u53d1\u6d88\u606f\uff0c@ \u5f15\u7528\uff0c/ \u6267\u884c\u52a8\u4f5c"],',
        '    ["Message subagent, @ to mention", "\u5411\u5b50\u667a\u80fd\u4f53\u53d1\u6d88\u606f\uff0c@ \u5f15\u7528"],',
        '    ["Listening. Ask anything.", "\u6b63\u5728\u8046\u542c\uff0c\u60f3\u95ee\u4ec0\u4e48\u90fd\u53ef\u4ee5\u3002"],',
        '    ["Analyzed", "\u5df2\u5206\u6790"],',
        '    ["Analyzing", "\u6b63\u5728\u5206\u6790"],',
        '    ["Editing", "\u6b63\u5728\u7f16\u8f91"],',
        '    ["Creating", "\u6b63\u5728\u521b\u5efa"],',
        '    ["Created", "\u5df2\u521b\u5efa"],',
        '    ["Updating", "\u6b63\u5728\u66f4\u65b0"],',
        '    ["Updated", "\u5df2\u66f4\u65b0"],',
        '    ["Deleting", "\u6b63\u5728\u5220\u9664"],',
        '    ["Reading", "\u6b63\u5728\u8bfb\u53d6"],',
        '    ["Writing", "\u6b63\u5728\u5199\u5165"],',
        '    ["Wrote", "\u5df2\u5199\u5165"],',
        '    ["Listing", "\u6b63\u5728\u5217\u51fa"],',
        '    ["Listed", "\u5df2\u5217\u51fa"],',
        '    ["Checking", "\u6b63\u5728\u68c0\u67e5"],',
        '    ["Checked", "\u5df2\u68c0\u67e5"],',
        '    ["Viewing", "\u6b63\u5728\u67e5\u770b"],',
        '    ["Viewed", "\u5df2\u67e5\u770b"],',
        '    ["Exploring", "\u6b63\u5728\u63a2\u7d22"],',
        '    ["Invoking", "\u6b63\u5728\u8c03\u7528"],',
        '    ["Invoked", "\u5df2\u8c03\u7528"],',
        '    ["Started", "\u5df2\u5f00\u59cb"],',
        '    ["Starting", "\u6b63\u5728\u542f\u52a8"],',
        '    ["Task Log", "\u4efb\u52a1\u65e5\u5fd7"],',
        '    ["Finished", "\u5df2\u5b8c\u6210"],',
        '    ["finished", "\u5df2\u5b8c\u6210"],'
    ) -join "`n"
    $js = Replace-Once -Text $js -Target '  const phrases = new Map([' -Replacement $phrasesAddon -Label 'phrases'

    $dynAddon = Resolve-OverlayUnicode (@(
        '  const dynamicPatterns = [',
        '    [/^(\d+)\s*s\s+ago$/i, ''$1\u79d2\u524d''],',
        '    [/^(\d+)\s*m\s+ago$/i, ''$1\u5206\u949f\u524d''],',
        '    [/^(\d+)\s*h\s+ago$/i, ''$1\u5c0f\u65f6\u524d''],',
        '    [/^(\d+)\s*d\s+ago$/i, ''$1\u5929\u524d''],',
        '    [/^(\d+)\s*w\s+ago$/i, ''$1\u5468\u524d''],',
        '    [/^(\d+)\s*mo\s+ago$/i, ''$1\u4e2a\u6708\u524d''],',
        '    [/^(\d+)\s*y\s+ago$/i, ''$1\u5e74\u524d''],',
        '    [/^(?:Just now|now)$/i, ''\u521a\u521a''],',
        '    [/^(Analyzed|Analyzing|Editing|Edited|Creating|Created|Updating|Updated|Deleting|Deleted|Reading|Writing|Wrote|Listing|Listed|Checking|Checked|Viewing|Viewed)\s+(Task\s+Logs?|[^\r\n]+?(?:\.[A-Za-z0-9]{1,8}(?:\s+#L\d+(?:-\d+)?)?|\s+#L\d+(?:-\d+)?)|[^\s\r\n]+)$/i, (_m, verb, target) => {',
        '      const verbMap = {',
        '        analyzed: ''\u5df2\u5206\u6790'', analyzing: ''\u6b63\u5728\u5206\u6790'', editing: ''\u6b63\u5728\u7f16\u8f91'', edited: ''\u5df2\u7f16\u8f91'',',
        '        creating: ''\u6b63\u5728\u521b\u5efa'', created: ''\u5df2\u521b\u5efa'', updating: ''\u6b63\u5728\u66f4\u65b0'', updated: ''\u5df2\u66f4\u65b0'',',
        '        deleting: ''\u6b63\u5728\u5220\u9664'', deleted: ''\u5df2\u5220\u9664'', reading: ''\u6b63\u5728\u8bfb\u53d6'', writing: ''\u6b63\u5728\u5199\u5165'',',
        '        wrote: ''\u5df2\u5199\u5165'', listing: ''\u6b63\u5728\u5217\u51fa'', listed: ''\u5df2\u5217\u51fa'', checking: ''\u6b63\u5728\u68c0\u67e5'',',
        '        checked: ''\u5df2\u68c0\u67e5'', viewing: ''\u6b63\u5728\u67e5\u770b'', viewed: ''\u5df2\u67e5\u770b'',',
        '      };',
        '      const zhVerb = verbMap[verb.toLowerCase()] || verb;',
        '      const zhTarget = /^Task\s+Logs?$/i.test(target) ? ''\u4efb\u52a1\u65e5\u5fd7'' : target;',
        '      return `${zhVerb} ${zhTarget}`;',
        '    }],',
        '    [/^([\s\S]{3,}?)(?<!\b(?:as|is|are|was|were|be|been|not|never|when|until|before|after|get|got|almost|completely|nearly|just|already))\s+finished$/i, ''$1 \u5df2\u5b8c\u6210''],'
    ) -join "`n")
    $js = Replace-Once -Text $js -Target '  const dynamicPatterns = [' -Replacement $dynAddon -Label 'dynamicPatterns_time'

    $agoAnchor = Resolve-OverlayUnicode (@(
        '    [/(\d+)\s*minutes?\s*ago\b/gi, ''$1 \u5206\u949f\u524d''],',
        '    [/(\d+)\s*hours?\s*ago\b/gi, ''$1 \u5c0f\u65f6\u524d''],',
        '    [/(\d+)\s*days?\s*ago\b/gi, ''$1 \u5929\u524d''],',
        '    [/(\d+)\s*weeks?\s*ago\b/gi, ''$1 \u5468\u524d''],',
        '    [/(\d+)\s*months?\s*ago\b/gi, ''$1 \u4e2a\u6708\u524d''],',
        '    [/(\d+)\s*years?\s*ago\b/gi, ''$1 \u5e74\u524d''],'
    ) -join "`n")
    $agoCompact = Resolve-OverlayUnicode (@(
        '    [/(\d+)\s*minutes?\s*ago\b/gi, ''$1\u5206\u949f\u524d''],',
        '    [/(\d+)\s*hours?\s*ago\b/gi, ''$1\u5c0f\u65f6\u524d''],',
        '    [/(\d+)\s*days?\s*ago\b/gi, ''$1\u5929\u524d''],',
        '    [/(\d+)\s*weeks?\s*ago\b/gi, ''$1\u5468\u524d''],',
        '    [/(\d+)\s*months?\s*ago\b/gi, ''$1\u4e2a\u6708\u524d''],',
        '    [/(\d+)\s*years?\s*ago\b/gi, ''$1\u5e74\u524d''],'
    ) -join "`n")
    $js = Replace-Once -Text $js -Target $agoAnchor -Replacement $agoCompact -Label 'existing_ago'

    $greetingAnchor = Resolve-OverlayUnicode (@(
        '    const greeting = trimmed.match(/^Hi ([\s\S]+?), what can we get done today\?$/);',
        '    if (greeting) return value.replace(trimmed, () => `\u4f60\u597d\uff0c${greeting[1]}\uff0c\u4eca\u5929\u60f3\u5b8c\u6210\u4ec0\u4e48\uff1f`);',
        '    if (/^\u4f60\u597d\uff0c[\s\S]+\uff0c\u4eca\u5929\u60f3\u5b8c\u6210\u4ec0\u4e48\uff1f$/.test(trimmed)) return value;'
    ) -join "`n")
    $greetingPatched = Resolve-OverlayUnicode (@(
        '    const greeting = trimmed.match(/^Hi ([\s\S]+?), what can we get done today\?$/);',
        '    if (greeting) return value.replace(trimmed, () => `\u4f60\u597d\uff0c${greeting[1]}\uff0c\u4eca\u5929\u60f3\u5b8c\u6210\u4ec0\u4e48\uff1f`);',
        '    if (trimmed === ''Hey there, what should we build today?'') return value.replace(trimmed, ''\u4f60\u597d\uff0c\u4eca\u5929\u60f3\u6784\u5efa\u4ec0\u4e48\uff1f'');',
        '    const heyNamed = trimmed.match(/^Hey ([\s\S]+?), what should we build today\?$/);',
        '    if (heyNamed && heyNamed[1].toLowerCase() !== ''there'') return value.replace(trimmed, () => `\u4f60\u597d\uff0c${heyNamed[1]}\uff0c\u4eca\u5929\u60f3\u6784\u5efa\u4ec0\u4e48\uff1f`);',
        '    if (trimmed === ''Welcome back. Where should we pick up?'') return value.replace(trimmed, ''\u6b22\u8fce\u56de\u6765\uff0c\u6211\u4eec\u4ece\u54ea\u91cc\u7ee7\u7eed\uff1f'');',
        '    const welcomeNamed = trimmed.match(/^Welcome back, ([\s\S]+?)\. Where should we pick up\?$/);',
        '    if (welcomeNamed) return value.replace(trimmed, () => `\u6b22\u8fce\u56de\u6765\uff0c${welcomeNamed[1]}\uff0c\u6211\u4eec\u4ece\u54ea\u91cc\u7ee7\u7eed\uff1f`);',
        '    if (trimmed === "Good to see you. What''s next?") return value.replace(trimmed, ''\u5f88\u9ad8\u5174\u89c1\u5230\u4f60\uff0c\u63a5\u4e0b\u6765\u505a\u4ec0\u4e48\uff1f'');',
        '    const goodSeeNamed = trimmed.match(/^Good to see you, ([\s\S]+?)\. What''s next\?$/);',
        '    if (goodSeeNamed) return value.replace(trimmed, () => `\u5f88\u9ad8\u5174\u89c1\u5230\u4f60\uff0c${goodSeeNamed[1]}\uff0c\u63a5\u4e0b\u6765\u505a\u4ec0\u4e48\uff1f`);',
        '    if (/^(?:\u4f60\u597d(?:\uff0c[\s\S]+)?\uff0c\u4eca\u5929\u60f3(?:\u5b8c\u6210|\u6784\u5efa)\u4ec0\u4e48\uff1f|\u6b22\u8fce\u56de\u6765(?:\uff0c[\s\S]+)?\uff0c\u6211\u4eec\u4ece\u54ea\u91cc\u7ee7\u7eed\uff1f|\u5f88\u9ad8\u5174\u89c1\u5230\u4f60(?:\uff0c[\s\S]+)?\uff0c\u63a5\u4e0b\u6765\u505a\u4ec0\u4e48\uff1f)$/.test(trimmed)) return value;'
    ) -join "`n")
    $js = Replace-Once -Text $js -Target $greetingAnchor -Replacement $greetingPatched -Label 'home_greetings'

    $skipAnchor = 'const historyItem = element.closest(''[data-testid="conversation-row-sidebar"], [data-cascade-id], '
    $skipFixed = 'const historyItem = element.closest(''[data-testid^="conversation-row-"], [data-testid="side-question-row"], [data-testid="subagent-node"], '
    $js = Replace-Once -Text $js -Target $skipAnchor -Replacement $skipFixed -Label 'historyItem_selector'

    $userSkipAnchor = Resolve-OverlayUnicode (@(
        '    // \u8df3\u8fc7\u7528\u6237\u8f93\u5165',
        '    if (element.closest(''[data-testid="user-input-step"], [aria-label="User message"], [aria-label="\u7528\u6237\u6d88\u606f"]'')) {',
        '      return true;',
        '    }'
    ) -join "`n")
    $userSkipPatched = Resolve-OverlayUnicode (@(
        '    // \u8df3\u8fc7\u7528\u6237\u8f93\u5165\u6c14\u6ce1\u6b63\u6587\uff08\u4fdd\u7559 user-message-actions \u65f6\u95f4\u6233\u4e0e\u64cd\u4f5c\u6309\u94ae\uff09',
        '    if (element.closest(''[data-testid="user-message-bubble"], [data-testid="user-message-content"], .agy-user-bubble, .agy-user-bubble-frame'')) {',
        '      return true;',
        '    }'
    ) -join "`n")
    $js = Replace-Once -Text $js -Target $userSkipAnchor -Replacement $userSkipPatched -Label 'user_input_skip'

    $agentRespAnchor = Resolve-OverlayUnicode (@(
        '    // \u8df3\u8fc7\u56de\u590d\u6b63\u6587\uff08\u4fdd\u7559\u63a7\u4ef6\u3001\u6298\u53e0\u6b65\u9aa4\u680f\u3001\u53d8\u66f4\u6982\u89c8\u4e0e\u7cfb\u7edf\u63d0\u793a\u5361\u7247\uff09',
        '    const agentResponse = element.closest(''[aria-label="Agent response"], [aria-label="\u667a\u80fd\u4f53\u56de\u590d"]'');',
        '    if (agentResponse) {',
        '      if (node.nodeType === Node.ELEMENT_NODE && element === agentResponse) return false;',
        '      const isInteractive = element.closest(''button, [role="button"], [class*="action"], [class*="button-container"], [data-testid="cleared-step-notice"], .files-changed-header'');'
    ) -join "`n")
    $agentRespPatched = Resolve-OverlayUnicode (@(
        '    const userStep = element.closest(''[data-testid="user-input-step"], [aria-label="User message"], [aria-label="\u7528\u6237\u6d88\u606f"]'');',
        '    if (userStep) {',
        '      if (node.nodeType === Node.ELEMENT_NODE && element === userStep) return false;',
        '      if (!element.closest(''[data-testid="user-message-actions"], [data-screenshot-volatile], button, [role="button"]'')) return true;',
        '    }',
        '',
        '    // \u8df3\u8fc7\u56de\u590d\u6b63\u6587\uff08\u4fdd\u7559\u63a7\u4ef6\u3001\u6298\u53e0\u6b65\u9aa4\u680f\u3001\u6d88\u606f\u64cd\u4f5c\u65f6\u95f4\u680f\u3001\u53d8\u66f4\u6982\u89c8\u4e0e\u7cfb\u7edf\u63d0\u793a\u5361\u7247\uff09',
        '    const agentResponse = element.closest(''[aria-label="Agent response"], [aria-label="\u667a\u80fd\u4f53\u56de\u590d"]'');',
        '    if (agentResponse) {',
        '      if (node.nodeType === Node.ELEMENT_NODE && element === agentResponse) return false;',
        '      const isInteractive = element.closest(''button, [role="button"], [class*="action"], [class*="button-container"], [data-testid="cascade-system-message-toolbar"], [data-screenshot-volatile], [data-testid="cleared-step-notice"], .files-changed-header'');'
    ) -join "`n")
    $js = Replace-Once -Text $js -Target $agentRespAnchor -Replacement $agentRespPatched -Label 'agent_resp_skip'

    $containerTarget = '    ''.antigravity-welcome-container'','
    $containerPatched = "    '.antigravity-welcome-container',`n    '[data-testid=""home-greeting""]',"
    $js = Replace-Once -Text $js -Target $containerTarget -Replacement $containerPatched -Label 'container_sel'

    $js = Replace-Once -Text $js -Target "    flushScheduler?.cancel();`n    restoreIdeNlsMessages();`n    removePreferenceSync?.();" -Replacement "    flushScheduler?.cancel();`n    clearTitleTimers();`n    restoreIdeNlsMessages();`n    removePreferenceSync?.();" -Label 'cleanup_timers'

    $restoreTarget = @(
        '  function restoreOriginals() {',
        '    const walker = document.createTreeWalker(document, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);',
        '    for (let node = walker.nextNode(); node; node = walker.nextNode()) {',
        '      restoreTrackedNode(node);',
        '    }',
        '  }'
    ) -join "`n"
    $restorePatched = @(
        '  function restoreOriginals() {',
        '    const walker = document.createTreeWalker(document, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);',
        '    for (let node = walker.nextNode(); node; node = walker.nextNode()) {',
        '      restoreTrackedNode(node);',
        '    }',
        '    restoreDocTitle();',
        '  }'
    ) -join "`n"
    $js = Replace-Once -Text $js -Target $restoreTarget -Replacement $restorePatched -Label 'restoreOriginals'

    $titleModule = @(
        '  const TITLE_MAP_KEY = "antigravityHansAutoTitleMap";',
        '  const CJK_CHAR_RE = /[\u3400-\u9fff\uf900-\ufaff\u3040-\u30ff\uac00-\ud7af]/;',
        '  let originalDocTitle = null;',
        '  let titleResyncTimers = [];',
        '  function clearTitleTimers() { for (const tid of titleResyncTimers) clearTimeout(tid); titleResyncTimers = []; }',
        '  function restoreDocTitle() { if (originalDocTitle !== null && typeof document !== "undefined") { document.title = originalDocTitle; originalDocTitle = null; } }',
        '  function loadAutoTitleMap() { try { const r = loadPref(TITLE_MAP_KEY); if (!r) return {}; const p = JSON.parse(r); return p && typeof p === "object" && !Array.isArray(p) ? p : {}; } catch (_e) { return {}; } }',
        '  function saveAutoTitleMap(m) { try { const es = Object.entries(m); savePref(TITLE_MAP_KEY, JSON.stringify(es.length > 200 ? Object.fromEntries(es.slice(-200)) : m)); } catch (_e) {} }',
        '  function isAutoEnglishTitle(raw) {',
        '    const s = (raw || "").trim();',
        '    if (s.length < 4 || s.length > 80 || CJK_CHAR_RE.test(s)) return false;',
        '    if (/[/\\]|https?:|^[~.]/i.test(s) || /\.[a-z0-9]{1,5}$/i.test(s)) return false;',
        '    if (!/^[A-Za-z0-9][A-Za-z0-9\s:&+\-/''"(),.?]{2,}$/.test(s)) return false;',
        '    const aw = s.split(/\s+/).filter(Boolean).filter((w) => /[A-Za-z]/.test(w));',
        '    if (aw.length < 2) return false;',
        '    const titled = aw.filter((w) => /^[A-Z]/.test(w) || /^(?:of|to|in|on|at|for|by|with|and|or|vs|the|a|an)$/i.test(w));',
        '    return titled.length / aw.length >= 0.7 && /^[A-Z0-9]/.test(aw[0]);',
        '  }',
        '  function extractFirstChineseUserPrompt(convoView) {',
        '    const step = convoView.querySelector(''[data-testid="user-input-step"]'') || convoView.querySelector(''[aria-label="User message"], [aria-label="\u7528\u6237\u6d88\u606f"]'');',
        '    if (!step) return "";',
        '    const skip = new Set(step.querySelectorAll(''button, [role="button"], [data-testid="queued-decorators"], [data-testid="user-message-actions"], [data-screenshot-volatile], time, svg''));',
        '    const parts = [];',
        '    const w = document.createTreeWalker(step, NodeFilter.SHOW_TEXT);',
        '    for (let n = w.nextNode(); n; n = w.nextNode()) {',
        '      let cur = n.parentElement, ign = false;',
        '      while (cur && cur !== step) { if (skip.has(cur)) { ign = true; break; } cur = cur.parentElement; }',
        '      if (ign) continue;',
        '      const t = (n.nodeValue || "").trim();',
        '      if (t && !/^\d+\s*(?:s|m|h|d)?\s*ago$/i.test(t) && t !== "You") parts.push(t);',
        '    }',
        '    const text = parts.join(" ").replace(/\s+/g, " ").trim();',
        '    const hm = text.match(/[\u4e00-\u9fff]/g);',
        '    return hm && hm.length >= 2 ? text : "";',
        '  }',
        '  function trimDirectiveTail(cs) {',
        '    const tr = /^(?:\u7ed9\u4e2a?.*\u4f8b\u5b50|\u4e3e\u4e2a?\u4f8b\u5b50|\u9644\u5e26?\u4f8b\u5b50|\u7b80\u77ed\u8bf4\u660e|\u7b80\u660e\u56de\u7b54|\u8bf4\u6e05.*|\u4e24\u4e09\u53e5\u8bdd.*|\u7528.*\u56de\u7b54|\u8bf7\u7b80\u8ff0|\u8c22\u8c22|\u611f\u8c22).*$/;',
        '    const f = cs.filter((c, i) => !(i > 0 && i === cs.length - 1 && tr.test(c)));',
        '    return f.length > 0 ? f : cs;',
        '  }',
        '  function deriveZhTitleFromPrompt(promptText) {',
        '    const clean = (promptText || "").replace(/\s+/g, " ").trim();',
        '    const ss = clean.split(/[\u3002\uff01\uff1f!?\n\uff1b;]+/).map((s) => s.trim()).filter(Boolean);',
        '    let first = ss.find((s) => (s.match(/[\u4e00-\u9fff]/g) || []).length >= 2) || "";',
        '    if (!first) return "";',
        '    const pfx = /^(?:\u4f60\u597d|\u60a8\u597d|\u8bf7\u95ee|\u9ebb\u70e6(?:\u4f60|\u60a8)?|\u8bf7(?:\u5e2e\u6211)?|\u5e2e\u6211|\u80fd\u4e0d\u80fd|\u53ef\u4ee5(?:\u5e2e\u6211)?|\u80fd\u5426|\u987a\u4fbf|\u6211\u60f3(?:\u95ee\u4e00\u4e0b|\u77e5\u9053|\u4e86\u89e3)?|\u60f3\u95ee(?:\u4e00\u4e0b)?|\u7528[\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341\u4e24\u51e0\d]+\u4e2a?[\u53e5\u5b57\u6bb5\u8bdd]+(?:\u6765\u8bb2|\u6765\u8bf4|\u8bf4|\u8bf4\u660e|\u89e3\u91ca|\u6982\u62ec)?|\u7b80\u77ed\u5730?|\u7b80\u5355\u5730?|\u901a\u4fd7\u5730?|\u8be6\u7ec6\u5730?|\u5feb\u901f\u5730?)[\uff0c,\s]*/;',
        '    const vrb = /^(?:\u8bb2\u4e00\u8bb2|\u8bb2\u8bb2|\u8bf4\u4e00\u8bf4|\u8bf4\u8bf4|\u89e3\u91ca\u4e00\u4e0b|\u89e3\u91ca\u4e0b|\u89e3\u91ca|\u4ecb\u7ecd\u4e00\u4e0b|\u4ecb\u7ecd\u4e0b|\u4ecb\u7ecd|\u804a\u4e00\u804a|\u804a\u804a|\u544a\u8bc9\u6211|\u56de\u7b54\u4e00\u4e0b|\u56de\u7b54|\u603b\u7ed3\u4e00\u4e0b|\u603b\u7ed3|\u5206\u6790\u4e00\u4e0b|\u5206\u6790|\u7ed9\u4e2a|\u5199\u4e00\u4e0b|\u5199\u4e2a)[\uff0c,\s]*/;',
        '    for (let i = 0; i < 4; i++) { const n = first.replace(pfx, "").trim(); if (n === first) break; if ((n.match(/[\u4e00-\u9fff]/g) || []).length >= 2) first = n; }',
        '    const av = first.replace(vrb, "").trim();',
        '    if ((av.match(/[\u4e00-\u9fff]/g) || []).length >= 2) first = av;',
        '    first = first.replace(/[\uff0c,\uff1a:\s]+$/, "");',
        '    if (first.length <= 18) return first;',
        '    let cs = trimDirectiveTail(first.split(/[\uff0c,]+/).map((c) => c.trim()).filter(Boolean));',
        '    const joined = cs.join("\uff0c");',
        '    if (joined.length <= 18) return joined;',
        '    const focus = /[\u51e0\u591a\u5c11\u600e\u4e3a\u4f55\u54ea\u8c01\u5417]/;',
        '    const fc = cs.find((c, idx) => idx > 0 && focus.test(c) && c.length >= 6 && c.length <= 18);',
        '    if (fc) return fc;',
        '    if (cs[0] && cs[0].length >= 6 && cs[0].length <= 18) return cs[0];',
        '    const cand = joined.slice(0, 17).replace(/[\uff0c,\u3001\s]+$/, "");',
        '    return cand ? cand + "\u2026" : "";',
        '  }',
        '  function findFirstVisibleTextNode(root) {',
        '    if (!root) return null;',
        '    const w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);',
        '    for (let n = w.nextNode(); n; n = w.nextNode()) { if (!n.parentElement?.closest?.("svg, input, textarea, [data-agy-hans-ui]") && (n.nodeValue || "").trim()) return n; }',
        '    return null;',
        '  }',
        '  function scheduleTitleResync() {',
        '    if (cancelled || lang !== "zh" || titleResyncTimers.length > 0) return;',
        '    titleResyncTimers.push(setTimeout(() => { if (!cancelled && lang === "zh") syncChineseConversationTitles(true); }, 1200));',
        '    titleResyncTimers.push(setTimeout(() => { titleResyncTimers = []; if (!cancelled && lang === "zh") syncChineseConversationTitles(true); }, 3200));',
        '  }',
        '  function syncChineseConversationTitles(fromTimer = false) {',
        '    if (cancelled || lang !== "zh" || typeof document === "undefined") return;',
        '    const titleMap = loadAutoTitleMap();',
        '    let mapChanged = false;',
        '    const convoView = document.querySelector(''[data-testid="conversation-view"], [data-testid="side-question-tab-conversation"]'');',
        '    const promptText = convoView ? extractFirstChineseUserPrompt(convoView) : "";',
        '    const segments = Array.from(document.querySelectorAll(''[data-testid="breadcrumb-segment"]''));',
        '    if (convoView && segments.length > 0) {',
        '      const seg = segments[segments.length - 1];',
        '      if (!seg.querySelector("input, textarea") && (seg.hasAttribute("data-tooltip-id") || segments.length >= 2 || promptText)) {',
        '        const tn = findFirstVisibleTextNode(seg);',
        '        if (tn) {',
        '          const tr = originals.texts.get(tn);',
        '          const orig = (tr ? tr.orig : (tn.nodeValue || "")).trim();',
        '          if (isAutoEnglishTitle(orig)) {',
        '            let zh = titleMap[orig];',
        '            if (!zh && promptText) { zh = deriveZhTitleFromPrompt(promptText); if (zh) { titleMap[orig] = zh; mapChanged = true; } }',
        '            if (zh) {',
        '              if (tn.nodeValue !== zh) writeText(tn, zh);',
        '              tn.__zh_patched = true;',
        '              if (document.title && document.title.includes(orig)) {',
        '                if (originalDocTitle === null) originalDocTitle = document.title;',
        '                const nt = originalDocTitle.includes(orig) ? originalDocTitle.replace(orig, () => zh) : document.title.replace(orig, () => zh);',
        '                if (document.title !== nt) document.title = nt;',
        '              }',
        '            }',
        '          }',
        '        }',
        '      }',
        '    }',
        '    if (!fromTimer && promptText) {',
        '      const lastSeg = segments[segments.length - 1];',
        '      const ctn = lastSeg ? findFirstVisibleTextNode(lastSeg) : null;',
        '      const cv = ctn ? (ctn.nodeValue || "").trim() : "";',
        '      if (!cv || !CJK_CHAR_RE.test(cv)) scheduleTitleResync();',
        '    }',
        '    for (const row of document.querySelectorAll(''[data-testid^="conversation-row-"], [data-testid="side-question-row"]'')) {',
        '      const w = document.createTreeWalker(row, NodeFilter.SHOW_TEXT);',
        '      for (let n = w.nextNode(); n; n = w.nextNode()) {',
        '        if (n.parentElement?.closest?.("svg, button")) continue;',
        '        const tr = originals.texts.get(n);',
        '        const raw = tr ? tr.orig : (n.nodeValue || "");',
        '        const t = raw.trim();',
        '        const mp = t ? titleMap[t] : "";',
        '        if (mp) { const nv = raw.replace(t, () => mp); if (n.nodeValue !== nv) writeText(n, nv); n.__zh_patched = true; }',
        '      }',
        '    }',
        '    if (mapChanged) saveAutoTitleMap(titleMap);',
        '  }',
        '  function applyChinese(resetMarks) {'
    ) -join "`n"
    $js = Replace-Once -Text $js -Target '  function applyChinese(resetMarks) {' -Replacement $titleModule -Label 'title_module'

    $js = Replace-Once -Text $js -Target "    translateNode(document);`n  }" -Replacement "    translateNode(document);`n    syncChineseConversationTitles();`n  }" -Label 'applyChinese_end'

    $flushTarget = @(
        '    flushScheduler = createFlushScheduler((batchNodes, batchElements) => {',
        "      if (cancelled || lang !== 'zh') return;",
        '      for (const node of batchNodes) translateNode(node);',
        '      for (const element of batchElements) translateElement(element);',
        '    });'
    ) -join "`n"
    $flushPatched = @(
        '    flushScheduler = createFlushScheduler((batchNodes, batchElements) => {',
        "      if (cancelled || lang !== 'zh') return;",
        '      for (const node of batchNodes) translateNode(node);',
        '      for (const element of batchElements) translateElement(element);',
        '      syncChineseConversationTitles();',
        '    });'
    ) -join "`n"
    $js = Replace-Once -Text $js -Target $flushTarget -Replacement $flushPatched -Label 'flushScheduler'

    $finalContent = $headerComment + "`n" + $js + "`n"
    $overlayDir = Split-Path -Parent $OverlayJs
    New-Item -ItemType Directory -Force -Path $overlayDir | Out-Null
    $tmpOverlay = Join-Path $overlayDir ('.antigravity-hans-overlay.' + [System.Guid]::NewGuid().ToString('N') + '.tmp')
    [System.IO.File]::WriteAllText($tmpOverlay, $finalContent, [System.Text.UTF8Encoding]::new($false))
    Move-Item -Force $tmpOverlay $OverlayJs
    return $true
}

function Find-OriginalExe {
    $candidates = @()
    if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe') }
    if (${env:ProgramFiles}) {
        $candidates += (Join-Path ${env:ProgramFiles} 'Antigravity\Antigravity.exe')
        $candidates += (Join-Path ${env:ProgramFiles} 'Google Antigravity\Antigravity.exe')
    }
    if (${env:ProgramFiles(x86)}) { $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Antigravity\Antigravity.exe') }
    foreach ($p in $candidates) {
        if ($p -and (Test-Path $p)) { return $p }
    }

    try {
        $wsh = New-Object -ComObject WScript.Shell
        foreach ($dir in @(([Environment]::GetFolderPath('Desktop')), ([Environment]::GetFolderPath('Programs')))) {
            if ([string]::IsNullOrWhiteSpace($dir)) { continue }
            $lnk = Join-Path $dir 'Antigravity.lnk'
            if (Test-Path $lnk) {
                $target = $wsh.CreateShortcut($lnk).TargetPath
                if ($target -and $target.EndsWith('\Antigravity.exe', [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $target)) {
                    return $target
                }
            }
        }
    } catch {}

    foreach ($regPath in @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )) {
        try {
            $items = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Antigravity*' }
            foreach ($item in $items) {
                if (-not [string]::IsNullOrWhiteSpace($item.InstallLocation)) {
                    $exeFromLoc = Join-Path $item.InstallLocation.Trim().Trim('"') 'Antigravity.exe'
                    if (Test-Path $exeFromLoc) { return $exeFromLoc }
                }
                if (-not [string]::IsNullOrWhiteSpace($item.DisplayIcon)) {
                    $exeFromIcon = ($item.DisplayIcon.Trim() -replace ',\s*-?\d+$', '').Trim().Trim('"')
                    if ($exeFromIcon -and $exeFromIcon.EndsWith('\Antigravity.exe', [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $exeFromIcon)) {
                        return $exeFromIcon
                    }
                }
            }
        } catch {}
    }

    return $null
}

function Get-SameSessionAntigravityPids {
    $mySession = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
    $pids = [int[]]@(
        Get-Process -Name 'Antigravity' -ErrorAction SilentlyContinue |
            Where-Object { $_.SessionId -eq $mySession } |
            ForEach-Object { [int]$_.Id }
    )
    return ,$pids
}

function Test-VisibleWindowForPids {
    param([int[]]$TargetPids)
    if ($null -eq $TargetPids -or $TargetPids.Count -eq 0) { return $false }
    $win32Code = @(
        'using System;',
        'using System.Runtime.InteropServices;',
        'public static class AgyWin32 {',
        '    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);',
        '    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);',
        '    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);',
        '    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);',
        '    public static bool HasVisibleWindow(int[] targetPids) {',
        '        if (targetPids == null || targetPids.Length == 0) return false;',
        '        bool found = false;',
        '        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {',
        '            if (!IsWindowVisible(hWnd)) return true;',
        '            uint pid = 0;',
        '            if (GetWindowThreadProcessId(hWnd, out pid) != 0 && Array.IndexOf(targetPids, (int)pid) >= 0) {',
        '                found = true;',
        '                return false;',
        '            }',
        '            return true;',
        '        }, IntPtr.Zero);',
        '        return found;',
        '    }',
        '}'
    ) -join "`n"
    if (-not ('AgyWin32' -as [type])) {
        try { Add-Type -TypeDefinition $win32Code -ErrorAction Stop } catch {}
    }
    if ('AgyWin32' -as [type]) {
        return [AgyWin32]::HasVisibleWindow($TargetPids)
    }
    return (@(Get-Process -Id $TargetPids -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero }).Count -gt 0)
}

function Test-DebugAntigravityRunning {
    $pids = @(Get-SameSessionAntigravityPids)
    if ($pids.Count -eq 0) { return $false }
    $cimProcs = @(Get-CimInstance Win32_Process -Filter "Name = 'Antigravity.exe'" -ErrorAction SilentlyContinue)
    foreach ($p in $cimProcs) {
        if ($pids -contains [int]$p.ProcessId -and $p.CommandLine -match '--remote-debugging-port=') {
            return $true
        }
    }
    return $false
}

function Stop-AntigravityProcessesByIds {
    param([int[]]$TargetPids)
    if ($null -eq $TargetPids -or $TargetPids.Count -eq 0) { return }
    Stop-Process -Id $TargetPids -Force -ErrorAction SilentlyContinue
    foreach ($id in $TargetPids) {
        if (Get-Process -Id $id -ErrorAction SilentlyContinue) {
            & taskkill.exe /F /PID $id 2>$null | Out-Null
        }
    }
    for ($i = 0; $i -lt 25; $i++) {
        if (@(Get-SameSessionAntigravityPids).Count -eq 0) { break }
        Start-Sleep -Milliseconds 200
    }
    Start-Sleep -Milliseconds 500
}

function Prepare-AntigravityForZhLaunch {
    param([bool]$NoGui = $false)
    if ((Test-ActiveHansMonitor) -or (Test-DebugAntigravityRunning)) {
        return $true
    }
    $pids = @(Get-SameSessionAntigravityPids)
    if ($pids.Count -eq 0) { return $true }

    $hasVisible = Test-VisibleWindowForPids -TargetPids $pids
    if (-not $hasVisible) {
        if (-not $NoGui) {
            $pidText = ($pids -join ', ')
            Write-Host "$TagWarn $(Resolve-ZhText '\u68c0\u6d4b\u5230 Antigravity \u65e0\u754c\u9762\u540e\u53f0\u8fdb\u7a0b') (PID: $pidText)$(Resolve-ZhText '\uff0c\u6b63\u5728\u81ea\u52a8\u6e05\u7406...')"
        }
        & taskkill.exe /IM Antigravity.exe 2>$null | Out-Null
        for ($i = 0; $i -lt 4; $i++) {
            if (@(Get-SameSessionAntigravityPids).Count -eq 0) { return $true }
            Start-Sleep -Milliseconds 200
        }
        $rem = @(Get-SameSessionAntigravityPids)
        if ($rem.Count -gt 0 -and -not (Test-VisibleWindowForPids -TargetPids $rem)) {
            Stop-AntigravityProcessesByIds -TargetPids $rem
        }
        return $true
    }

    if ($NoGui) {
        $wsh = New-Object -ComObject WScript.Shell
        $msg = Resolve-ZhText '\u68c0\u6d4b\u5230\u539f\u7248 Antigravity \u7a97\u53e3\u6b63\u5728\u8fd0\u884c\uff08\u672a\u5f00\u542f\u4e2d\u6587\u8c03\u8bd5\u7aef\u53e3\uff09\u3002\n\n\u662f\u5426\u4fdd\u5b58\u72b6\u6001\u5e76\u91cd\u542f\u4e3a\u300cAntigravity \u4e2d\u6587\u300d\uff1f'
        $title = Resolve-ZhText 'Antigravity \u4e2d\u6587'
        $ans = $wsh.Popup($msg, 0, $title, 0x1024)
        if ($ans -ne 6) { return $false }
    } else {
        Write-Host "$TagWarn $(Resolve-ZhText '\u6b63\u5728\u8bf7\u6c42\u5df2\u8fd0\u884c\u7684 Antigravity \u4fdd\u5b58\u72b6\u6001\u5e76\u9000\u51fa...')"
    }

    & taskkill.exe /IM Antigravity.exe 2>$null | Out-Null
    for ($i = 0; $i -lt 25; $i++) {
        $cur = @(Get-SameSessionAntigravityPids)
        if ($cur.Count -eq 0) { return $true }
        if (-not (Test-VisibleWindowForPids -TargetPids $cur)) { break }
        Start-Sleep -Milliseconds 200
    }
    $rem = @(Get-SameSessionAntigravityPids)
    if ($rem.Count -gt 0 -and ($NoGui -or -not (Test-VisibleWindowForPids -TargetPids $rem))) {
        Stop-AntigravityProcessesByIds -TargetPids $rem
    }
    return $true
}

function New-ZhShortcut {
    $targets = @(
        ([Environment]::GetFolderPath('Desktop')),
        ([Environment]::GetFolderPath('Programs'))
    )
    $wsh = New-Object -ComObject WScript.Shell
    $vbsPath = Join-Path $PSScriptRoot 'agy-zh-launch.vbs'
    if ($LaunchVbsB64 -and -not $LaunchVbsB64.Contains('__LAUNCH_VBS')) {
        $vbsText = [System.Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($LaunchVbsB64))
        [System.IO.File]::WriteAllText($vbsPath, $vbsText, [System.Text.UTF8Encoding]::new($false))
    }
    $origExe = Find-OriginalExe
    $desc = Resolve-ZhText '\u4ee5\u4e2d\u6587\u754c\u9762\u4e0e\u5168\u6d41\u7a0b\u4e2d\u6587\u601d\u8003\u63d0\u793a\u8bcd\u542f\u52a8 Antigravity'
    $wscriptExe = Join-Path $env:SystemRoot 'System32\wscript.exe'

    foreach ($dir in $targets) {
        if ([string]::IsNullOrWhiteSpace($dir)) { continue }
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $lnkPath = Join-Path $dir $ShortcutName
        $sc = $wsh.CreateShortcut($lnkPath)
        $sc.TargetPath = $wscriptExe
        $sc.Arguments = "//B //NoLogo `"$vbsPath`""
        $sc.WorkingDirectory = $PSScriptRoot
        $sc.WindowStyle = 7
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
        $isNoGui = ($RestArgs -contains '--nogui')
        if (-not (Prepare-AntigravityForZhLaunch -NoGui $isNoGui)) {
            break
        }
        try { Ensure-EnhancedOverlay | Out-Null } catch {}
        if (Test-Path (Join-Path $PluginDir 'plugin.json')) {
            Set-ZhPluginEnabled -Enabled $true
        }
        $argsList = @('--app')
        if (Test-Path $OverlayJs) {
            $argsList += '--trust-external-overlay'
        }
        if ($isNoGui) {
            $argsList += '--nogui'
        }
        try {
            if ($isNoGui) {
                $logDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'logs'
                New-Item -ItemType Directory -Force -Path $logDir | Out-Null
                $stdOutLog = Join-Path $logDir 'antigravity-hans.log'
                $stdErrLog = Join-Path $logDir 'antigravity-hans.err.log'
                $startedAt = [DateTime]::UtcNow
                $proc = Start-Process -FilePath $HansExe -ArgumentList $argsList -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardOutput $stdOutLog -RedirectStandardError $stdErrLog -PassThru
                $proc.WaitForExit()
                if ((([DateTime]::UtcNow - $startedAt).TotalSeconds -lt 12) -and -not (Test-ActiveHansMonitor) -and -not (Test-DebugAntigravityRunning)) {
                    $errTag = Resolve-ZhText '[\u9519\u8bef]'
                    $logLines = @()
                    foreach ($lp in @($stdOutLog, $stdErrLog)) {
                        if (Test-Path $lp) {
                            $logLines += @(Get-Content -Path $lp -Encoding UTF8 -ErrorAction SilentlyContinue)
                        }
                    }
                    $errLine = ($logLines | Where-Object { $_ -and $_.Contains($errTag) } | Select-Object -Last 1)
                    if (-not $errLine) {
                        $errLine = ($logLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 1)
                    }
                    if ($proc.ExitCode -ne 0 -or $errLine) {
                        $detail = if ($errLine) { $errLine } else { "ExitCode=$($proc.ExitCode)" }
                        $popTitle = Resolve-ZhText 'Antigravity \u4e2d\u6587\u542f\u52a8\u5931\u8d25'
                        $popMsg = "$(Resolve-ZhText '\u542f\u52a8 Antigravity \u4e2d\u6587\u5931\u8d25\uff1a')`n$detail`n`n$(Resolve-ZhText '\u8be6\u7ec6\u65e5\u5fd7\uff1a')$stdOutLog"
                        $null = (New-Object -ComObject WScript.Shell).Popup($popMsg, 0, $popTitle, 0x1010)
                    }
                }
            } else {
                & $HansExe @argsList
            }
        } finally {
            Start-Sleep -Milliseconds 300
            if (-not (Test-ActiveHansMonitor)) {
                Set-ZhPluginEnabled -Enabled $false
            }
        }
    }
    'build-overlay' {
        $forceFlag = ($RestArgs -contains '--force')
        Ensure-EnhancedOverlay -Force $forceFlag | Out-Null
        Write-Host "$TagOk $(Resolve-ZhText '\u5df2\u751f\u6210\u589e\u5f3a\u6c49\u5316\u8986\u76d6\u811a\u672c:') $OverlayJs"
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
        Write-Host "$(Resolve-ZhText '\u589e\u5f3a\u6c49\u5316\u8986\u76d6\u811a\u672c   : ') $(if (Test-Path $OverlayJs) { "$(Resolve-ZhText '\u5df2\u5c31\u7eea ')($OverlayJs)" } else { Resolve-ZhText '\u672a\u751f\u6210\uff08\u53ef\u8fd0\u884c agy-zh build-overlay \u751f\u6210\uff09' })"
        Write-Host "$(Resolve-ZhText '\u4e2d\u6587\u601d\u8003\u63d0\u793a\u8bcd\u63d2\u4ef6 : ') $(if (Test-Path (Join-Path $PluginDir 'plugin.json')) { "$(Resolve-ZhText '\u5df2\u5b89\u88c5 ')($PluginDir)" } else { Resolve-ZhText '\u672a\u5b89\u88c5' })"
        Write-Host "$(Resolve-ZhText '\u63d0\u793a\u8bcd\u5f53\u524d\u5f00\u5173\u72b6\u6001 : ') $(if ($st) { Resolve-ZhText '\u5df2\u5f00\u542f (enabled: true)' } else { Resolve-ZhText '\u5df2\u5173\u95ed (enabled: false\uff0c\u539f\u7248\u5165\u53e3\u7eaf\u51c0)' })"
        Write-Host "$(Resolve-ZhText '\u540e\u53f0\u6c49\u5316\u76d1\u89c6\u5668\u8fdb\u7a0b : ') $(if ($active) { Resolve-ZhText '\u8fd0\u884c\u4e2d' } else { Resolve-ZhText '\u672a\u8fd0\u884c' })"
    }
    default {
        Write-Host (Resolve-ZhText 'agy-zh - Antigravity \u53cc\u5165\u53e3\u65e0\u635f\u6c49\u5316\u4e0e\u4e2d\u6587\u601d\u8003\u63d0\u793a\u8bcd\u8054\u52a8\u542f\u52a8\u5668 (Windows)')
        Write-Host (Resolve-ZhText '\u7528\u6cd5: agy-zh <start|stop|status|prompt <on|off|status>|build-overlay|shortcut>')
    }
}
'@

    $FinalAgyZhScript = $AgyZhScript.Replace('__LAUNCH_VBS_B64__', $LaunchVbsB64)
    [System.IO.File]::WriteAllText($AgyZhPs1, $FinalAgyZhScript + "`r`n", [System.Text.UTF8Encoding]::new($false))
    $CmdContent = "@echo off`r`n`"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`" -NoProfile -ExecutionPolicy Bypass -File `"%~dp0agy-zh.ps1`" %*`r`n"
    [System.IO.File]::WriteAllText($AgyZhCmd, $CmdContent, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($AgyZhVbs, $LaunchVbsContent + "`r`n", [System.Text.UTF8Encoding]::new($false))

    # 4. Add BinDir to User Path and current session Path if missing
    $normalizedBin = $BinDir.TrimEnd('\')
    $pathContainsBin = {
        param([string]$PathValue)
        if ([string]::IsNullOrWhiteSpace($PathValue)) { return $false }
        foreach ($seg in ($PathValue -split ';')) {
            if (-not [string]::IsNullOrWhiteSpace($seg) -and $seg.Trim().TrimEnd('\').Equals($normalizedBin, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
        return $false
    }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not (& $pathContainsBin $userPath)) {
        $segments = @()
        if ($userPath) {
            $segments = @($userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
        $newUserPath = (($segments + $BinDir) -join ';')
        [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
        Write-Host "$TagOk $(Resolve-ZhText '\u5df2\u5c06\u547d\u4ee4\u884c\u76ee\u5f55\u52a0\u5165\u7528\u6237 Path:') $BinDir"
    }
    if (-not (& $pathContainsBin $env:Path)) {
        if ($env:Path) { $env:Path = "$env:Path;$BinDir" } else { $env:Path = $BinDir }
    }

    # 5. Build enhanced overlay and keep plugin disabled by default (stock entry stays clean)
    & $PsExe -NoProfile -ExecutionPolicy Bypass -File $AgyZhPs1 build-overlay --force
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
