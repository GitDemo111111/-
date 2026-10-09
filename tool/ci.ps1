<#
.SYNOPSIS
  本地 CI：格式检查 -> 静态分析 -> 测试 -> 构建 Release APK/AAB。

.DESCRIPTION
  和 .github/workflows/ci.yml 做同样的事情，方便在推代码前先跑一遍。

.EXAMPLE
  pwsh -File tool/ci.ps1
  pwsh -File tool/ci.ps1 -SkipBuild
  pwsh -File tool/ci.ps1 -FlutterPath "C:\flutter\bin\flutter.bat" -JavaHome "C:\Program Files\Android\Android Studio\jbr"
#>
[CmdletBinding()]
param(
    # flutter 可执行文件；默认用 PATH 里的 flutter。
    [string]$FlutterPath = 'flutter',

    # JDK 17+ 的根目录；不传时会尝试常见的 Android Studio 自带 JBR。
    [string]$JavaHome,

    # 只做检查，不构建 APK。
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

$script:failures = 0

function Write-Header([string]$text) {
    Write-Host ''
    Write-Host "==============================================================" -ForegroundColor DarkCyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host "==============================================================" -ForegroundColor DarkCyan
}

function Invoke-Step {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action
    )
    Write-Header $Name
    $started = Get-Date
    try {
        & $Action
        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
            throw "退出码 $LASTEXITCODE"
        }
        $elapsed = ((Get-Date) - $started).TotalSeconds
        Write-Host ("[OK]   {0}  ({1:N1}s)" -f $Name, $elapsed) -ForegroundColor Green
    }
    catch {
        $elapsed = ((Get-Date) - $started).TotalSeconds
        Write-Host ("[FAIL] {0}  ({1:N1}s) -> {2}" -f $Name, $elapsed, $_.Exception.Message) -ForegroundColor Red
        $script:failures++
    }
}

Write-Header '环境准备'

if (-not $JavaHome) {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Android\Android Studio\jbr'),
        (Join-Path ${env:ProgramFiles(x86)} 'Android\Android Studio\jbr'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Android Studio\jbr'),
        'D:\Android Studio\jbr'
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path (Join-Path $candidate 'bin\java.exe'))) {
            $JavaHome = $candidate
            break
        }
    }
}
if ($JavaHome) {
    $env:JAVA_HOME = $JavaHome
    Write-Host "JAVA_HOME = $JavaHome"
}
else {
    Write-Host 'JAVA_HOME 未设置，将使用系统默认 JDK（需要 17 或更高）。' -ForegroundColor Yellow
}

Write-Host "工作目录 = $projectRoot"
Write-Host "Flutter  = $FlutterPath"

# 找到 dart：优先从 flutter 路径推导，其次用 PATH 里的 dart。
$dartPath = 'dart'
if (Test-Path $FlutterPath) {
    $candidate = Join-Path (Split-Path -Parent $FlutterPath) 'cache\dart-sdk\bin\dart.exe'
    if (Test-Path $candidate) { $dartPath = $candidate }
}
Write-Host "Dart     = $dartPath"

Invoke-Step '拉取依赖 (flutter pub get)' {
    & $FlutterPath pub get
}

Invoke-Step '检查代码格式 (dart format)' {
    & $dartPath format --output=none --set-exit-if-changed lib test integration_test
}

Invoke-Step '静态分析 (flutter analyze)' {
    & $FlutterPath analyze --fatal-infos
}

Invoke-Step '运行测试 (flutter test --coverage)' {
    & $FlutterPath test --coverage --reporter compact
}

if (-not $SkipBuild) {
    Invoke-Step '构建 Release APK' {
        & $FlutterPath build apk --release
    }
    Invoke-Step '构建 Release AAB' {
        & $FlutterPath build appbundle --release
    }
}

Write-Header '结果'
if ($script:failures -eq 0) {
    Write-Host '全部通过 ✅' -ForegroundColor Green
    if (-not $SkipBuild) {
        Get-ChildItem 'build\app\outputs\flutter-apk\*.apk', 'build\app\outputs\bundle\release\*.aab' -ErrorAction SilentlyContinue |
            ForEach-Object { Write-Host ("  {0}  ({1:N1} MB)" -f $_.FullName, ($_.Length / 1MB)) }
    }
    $exitCode = 0
}
else {
    Write-Host "$script:failures 个步骤失败 ❌" -ForegroundColor Red
    $exitCode = 1
}

Pop-Location
exit $exitCode
