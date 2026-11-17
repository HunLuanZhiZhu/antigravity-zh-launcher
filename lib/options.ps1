# Shared argument parser; compatible with Windows PowerShell 5.1 and PowerShell 7.
function Read-AgyOptions {
    param([string[]]$Arguments, [string[]]$Switches = @(), [switch]$Runtime)
    $result = @{ Lang = 'zh-CN'; Rest = @() }
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $arg = $Arguments[$i]
        if ($arg -in @('--lang', '-Lang')) {
            if (++$i -ge $Arguments.Count) { throw '--lang requires a language code.' }
            $result.Lang = $Arguments[$i]
        } elseif ($arg -like '--lang=*') {
            $result.Lang = $arg.Substring(7)
        } elseif ($arg -in @('--help', '-h', '-Help')) {
            $result.Help = $true
        } elseif ($arg -in $Switches) {
            $result[$arg.TrimStart('-').Replace('-', '').ToLowerInvariant()] = $true
        } elseif ($Runtime) {
            $result.Rest += $arg
        } else {
            throw "Unknown argument: $arg"
        }
    }
    if ($result.Lang -cnotin @('zh-CN','zh-TW','ja','ko','es','fr','de','ru','pt-BR')) {
        throw "Unsupported language: $($result.Lang). Supported: zh-CN zh-TW ja ko es fr de ru pt-BR"
    }
    return $result
}
