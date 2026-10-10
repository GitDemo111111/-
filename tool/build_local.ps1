# 本机构建 APK（一键脚本）
#
# 为什么要这么绕：这台机器上 C:\Users\... 下的文本文件对 java.exe 是**密文**
# （透明加密，见 本机构建修复记录.md），而 AGP 必须用 Java 读 R.txt，
# 所以工程放在 C 盘永远构建不出来。放到 D 盘就一切正常。
#
# 用法：
#   pwsh -ExecutionPolicy Bypass -File tool\build_local.ps1
#   pwsh -ExecutionPolicy Bypass -File tool\build_local.ps1 -SplitPerAbi
#   pwsh -ExecutionPolicy Bypass -File tool\build_local.ps1 -Install   # 顺带 adb 安装

param(
    [string]$BuildRoot = 'D:\Deskstop\birthday_keeper',
    [string]$FlutterSdk = 'D:\Deskstop\flutter-sdk',
    [string]$AndroidSdk = 'C:\Users\feasycom\dev\android-sdk',
    [string]$JavaHome = 'D:\Android Studio\jbr',
    [string]$OutputDir = (Join-Path $env:USERPROFILE 'Documents\生日管家APK'),
    [switch]$SplitPerAbi,
    [switch]$Install
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

function Write-Step($text) { Write-Host "==> $text" -ForegroundColor Cyan }

# ---------------------------------------------------------------- 同步到 D 盘
Write-Step "同步工程到 D 盘（构建必须在 D:，否则 Java 读到密文）"
Write-Host "    $projectRoot  ->  $BuildRoot"
robocopy $projectRoot $BuildRoot /MIR /XD build .dart_tool .git .idea /NFL /NDL /NJH /NJS /R:1 /W:1 /MT:16 | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy 失败（exit $LASTEXITCODE）" }

Write-Step "写本机专用的 android/local.properties"
$localProps = @(
    "sdk.dir=$($AndroidSdk -replace '\\', '\\' -replace ':', '\:')",
    "flutter.sdk=$($FlutterSdk -replace '\\', '\\')"
) -join "`n"
[System.IO.File]::WriteAllText(
    (Join-Path $BuildRoot 'android\local.properties'),
    $localProps + "`n",
    (New-Object System.Text.UTF8Encoding($false))
)

# ---------------------------------------------------------------- 构建
$env:JAVA_HOME = $JavaHome
$env:ANDROID_HOME = $AndroidSdk
$env:ANDROID_SDK_ROOT = $AndroidSdk
$env:JAVA_TOOL_OPTIONS = '-Dfile.encoding=UTF-8'

$flutter = Join-Path $FlutterSdk 'bin\flutter.bat'
if (-not (Test-Path $flutter)) { throw "找不到 Flutter SDK：$flutter" }

$log = Join-Path $BuildRoot 'build_local.log'
$buildArgs = @('build', 'apk', '--release', '--android-skip-build-dependency-validation')
if ($SplitPerAbi) { $buildArgs += '--split-per-abi' }

Write-Step "构建 Release APK（日志：$log）"
# 不能写成 `& $flutter @buildArgs *> $log`：flutter.bat 会往 stderr 打一行
# 仓库提示，而 $ErrorActionPreference='Stop' 会把原生命令的 stderr 当终止错误，
# 脚本会在构建刚开始时直接退出。交给 cmd 重定向最省事。
$quotedArgs = ($buildArgs | ForEach-Object {
    if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
}) -join ' '
$commandLine = '"' + $flutter + '" ' + $quotedArgs + ' > "' + $log + '" 2>&1'
Push-Location $BuildRoot
try {
    cmd /c $commandLine
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}

$apkDir = Join-Path $BuildRoot 'build\app\outputs\flutter-apk'
$apks = @(Get-ChildItem (Join-Path $apkDir '*.apk') -ErrorAction SilentlyContinue)
if ($code -ne 0 -or $apks.Count -eq 0) {
    Write-Host "构建失败（exit $code），日志尾部：" -ForegroundColor Red
    Get-Content $log -Tail 30 | ForEach-Object { Write-Host "    $_" }
    exit 1
}

# ---------------------------------------------------------------- 校验 + 归档
$buildTools = Get-ChildItem (Join-Path $AndroidSdk 'build-tools') -Directory |
    Sort-Object Name -Descending | Select-Object -First 1
$apksigner = Join-Path $buildTools.FullName 'apksigner.bat'
$aapt2 = Join-Path $buildTools.FullName 'aapt2.exe'

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$version = (Select-String -Path (Join-Path $BuildRoot 'pubspec.yaml') -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$versionName = $version.Split('+')[0]

foreach ($apk in $apks) {
    Write-Step "校验 $($apk.Name)"
    & $apksigner verify $apk.FullName
    if ($LASTEXITCODE -ne 0) { throw "签名校验失败：$($apk.FullName)（不要安装！）" }

    $abi = ''
    if ($apk.Name -match 'arm64-v8a') { $abi = '-arm64' }
    elseif ($apk.Name -match 'armeabi-v7a') { $abi = '-arm32' }

    $target = Join-Path $OutputDir "生日管家-v$versionName$abi.apk"
    Copy-Item $apk.FullName $target -Force
    Copy-Item $apk.FullName (Join-Path $OutputDir 'app-release.apk') -Force

    $badging = & $aapt2 dump badging $apk.FullName 2>&1 |
        Select-String -Pattern "^package:" | Select-Object -First 1
    Write-Host "    产物: $target"
    Write-Host "    $($badging.Line.Trim())"
    Write-Host "    sha256: $((Get-FileHash $target -Algorithm SHA256).Hash)"
}

# ---------------------------------------------------------------- 可选：装到手机
if ($Install) {
    $adb = Join-Path $AndroidSdk 'platform-tools\adb.exe'
    $devices = & $adb devices | Select-String -Pattern "\tdevice$"
    if (-not $devices) {
        Write-Host "没有检测到已连接的手机（adb devices 为空），跳过安装。" -ForegroundColor Yellow
    } else {
        $target = Join-Path $OutputDir "生日管家-v$versionName.apk"
        if (-not (Test-Path $target)) { $target = (Get-ChildItem (Join-Path $OutputDir '*.apk') | Select-Object -First 1).FullName }
        Write-Step "安装到手机：$target"
        & $adb install -r $target
        if ($LASTEXITCODE -ne 0) {
            Write-Host "覆盖安装失败（多半是签名不同）。保留数据重装：" -ForegroundColor Yellow
            & $adb shell pm uninstall -k --user 0 com.birthdaykeeper.birthday_keeper
            & $adb install $target
        }
        & $adb shell dumpsys package com.birthdaykeeper.birthday_keeper |
            Select-String -Pattern 'versionName|versionCode' | Select-Object -First 2 |
            ForEach-Object { Write-Host "    手机上: $($_.Line.Trim())" }
    }
}

Write-Host ""
Write-Host "完成。APK 在：$OutputDir" -ForegroundColor Green
