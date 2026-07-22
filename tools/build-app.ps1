param(
    [ValidateSet('all', 'arm64', 'x64')]
    [string]$Architecture = 'all',
    # release 会同时让 Rust 走 --release（thin LTO + strip）并让 hvigor 走 release 构建模式。
    [ValidateSet('debug', 'release')]
    [string]$BuildMode = 'debug',
    [switch]$SkipRust
)

$ErrorActionPreference = 'Stop'
$Workspace = Split-Path -Parent $PSScriptRoot
$DevEcoRoot = if ($env:DEVECO_HOME) { $env:DEVECO_HOME } else { 'C:\Program Files\Huawei\DevEco Studio' }
$env:DEVECO_SDK_HOME = Join-Path $DevEcoRoot 'sdk'
$env:JAVA_HOME = Join-Path $DevEcoRoot 'jbr'
$env:PATH = "$(Join-Path $env:JAVA_HOME 'bin');$($env:PATH)"

if (-not $SkipRust) {
    if ($Architecture -in @('all', 'arm64')) {
        & (Join-Path $PSScriptRoot 'build-native.ps1') -Target ohos-arm64 -Profile $BuildMode
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    if ($Architecture -in @('all', 'x64')) {
        & (Join-Path $PSScriptRoot 'build-native.ps1') -Target ohos-x64 -Profile $BuildMode
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
}

$Ohpm = Join-Path $DevEcoRoot 'tools\ohpm\bin\ohpm.bat'
$Hvigor = Join-Path $DevEcoRoot 'tools\hvigor\bin\hvigorw.bat'
& $Ohpm install --all
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $Hvigor --mode module -p product=default -p module=entry@default `
    -p buildMode=$BuildMode assembleHap --no-daemon
exit $LASTEXITCODE
