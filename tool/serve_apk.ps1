<#
.SYNOPSIS
  把构建出来的 APK 通过局域网共享出去，手机扫码/输网址就能下载安装。

.DESCRIPTION
  会做三件事：
    1. 找到最新的 APK（默认 build/app/outputs/flutter-apk/*.apk）；
    2. 生成一个带下载按钮的简单页面（顺手把当前版本、大小、SHA256 也列出来）；
    3. 用 Python 起一个绑在 0.0.0.0 的静态服务，让同一 Wi-Fi 下的手机能访问。

.EXAMPLE
  pwsh -File tool/serve_apk.ps1
  pwsh -File tool/serve_apk.ps1 -Port 8090
  pwsh -File tool/serve_apk.ps1 -ApkPath C:\path\to\app-release.apk
#>
[CmdletBinding()]
param(
    [int]$Port = 8090,
    [string]$ApkPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not $ApkPath) {
    $found = Get-ChildItem "$projectRoot\build\app\outputs\flutter-apk\*.apk" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    if (-not $found) {
        Write-Host '没有找到 APK。' -ForegroundColor Red
        Write-Host '请先构建：' -ForegroundColor Yellow
        Write-Host '  pwsh -File tool/ci.ps1        # 分析 + 测试 + 构建' -ForegroundColor Yellow
        Write-Host '  flutter build apk --release   # 只构建' -ForegroundColor Yellow
        exit 1
    }
    $ApkPath = $found[0].FullName
}

if (-not (Test-Path $ApkPath)) {
    Write-Host "APK 不存在：$ApkPath" -ForegroundColor Red
    exit 1
}

$apk = Get-Item $ApkPath
$sizeMb = [math]::Round($apk.Length / 1MB, 1)
$sha256 = (Get-FileHash $apk.FullName -Algorithm SHA256).Hash

# 共享前先验签名：用多线程分片下载拼出来的 APK 表面看没问题，
# 但手机安装会报 INSTALL_PARSE_FAILED_NO_CERTIFICATES。
$sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { 'C:\Users\feasycom\dev\android-sdk' }
$bt = Get-ChildItem (Join-Path $sdkRoot 'build-tools') -Directory -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1
if ($bt) {
    $signer = Join-Path $bt.FullName 'apksigner.bat'
    if (Test-Path $signer) {
        & $signer verify $apk.FullName *> $null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "!! 这个 APK 签名校验失败，文件可能已损坏，别急着装：$($apk.FullName)" -ForegroundColor Red
            Write-Host "   重新构建：pwsh -File tool\build_local.ps1" -ForegroundColor Yellow
        } else {
            Write-Host "签名校验：通过" -ForegroundColor Green
        }
    }
}

# 分享目录：保持 ASCII 文件名，避免手机上出现乱码
$shareDir = Join-Path $env:TEMP 'birthday_keeper_share'
if (Test-Path $shareDir) { Remove-Item $shareDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $shareDir | Out-Null

# 用 APK 自己的文件名（保证页面上写的版本和真正装上去的一致）。
# 之前这里写死成 1.0.0，导致换了包之后页面还显示旧版本号。
$fileName = $apk.Name
# 版本号从文件名里取：birthday-keeper-1.2.0[-arm64-v8a].apk -> 1.2.0
$versionMatch = [regex]::Match($fileName, '^birthday-keeper-([0-9]+(?:\.[0-9]+)*)')
$version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { '未知' }
# 架构后缀（分架构包才有）
$abiMatch = [regex]::Match($fileName, '(arm64-v8a|armeabi-v7a|x86_64)')
$abi = if ($abiMatch.Success) { $abiMatch.Groups[1].Value } else { '通用（含全部架构）' }
Copy-Item $apk.FullName (Join-Path $shareDir $fileName) -Force

# 找一块真实的局域网网卡地址（排除回环 / VMware 虚拟网卡）
$ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
        $_.IPAddress -notlike '127.*' -and
        $_.IPAddress -notlike '169.254.*' -and
        $_.InterfaceAlias -notmatch 'VMware|Loopback|vEthernet'
    } | Select-Object -First 1).IPAddress
if (-not $ip) { $ip = '<本机局域网IP>' }

$built = $apk.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')

$html = @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>安装生日管家</title>
  <style>
    * { box-sizing: border-box; }
    body {
      margin: 0; padding: 32px 20px; min-height: 100vh;
      font-family: -apple-system, "Segoe UI", "Microsoft YaHei", sans-serif;
      background: linear-gradient(160deg, #0084FF 0%, #57B0FF 55%, #F3F9FF 55.1%);
      color: #0B2545;
    }
    .card {
      max-width: 460px; margin: 40px auto 0; background: #fff;
      border-radius: 22px; padding: 28px 24px;
      box-shadow: 0 18px 48px rgba(0, 60, 130, .22);
    }
    h1 { margin: 0 0 6px; font-size: 24px; }
    .sub { color: #5C7A9E; font-size: 13.5px; margin-bottom: 22px; }
    a.dl {
      display: block; text-align: center; text-decoration: none;
      background: #0084FF; color: #fff; font-size: 18px; font-weight: 800;
      padding: 17px; border-radius: 14px;
      box-shadow: 0 8px 20px rgba(0, 132, 255, .35);
    }
    a.dl:active { transform: translateY(1px); }
    .meta { margin-top: 18px; font-size: 12.5px; color: #5C7A9E; line-height: 1.9; }
    .meta code { background: #EAF4FF; padding: 2px 6px; border-radius: 6px; color: #0B2545; word-break: break-all; }
    .tip { margin-top: 18px; background: #D8ECFF; color: #0057B8; border-radius: 12px;
           padding: 12px 14px; font-size: 12.5px; line-height: 1.6; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🎂 生日管家</h1>
    <div class="sub">记录亲友生日，生日前 3 天和当天提醒你</div>
    <a class="dl" href="$fileName" download>下载 APK 并安装</a>
    <div class="meta">
      版本：<code>$version</code><br>
      架构：<code>$abi</code><br>
      文件：<code>$fileName</code><br>
      大小：<code>$sizeMb MB</code><br>
      构建时间：<code>$built</code><br>
      SHA256：<code>$sha256</code>
    </div>
    <div class="tip">
      手机首次安装需要在系统里允许「安装未知应用 / 来自此来源的应用」。<br>
      安装后打开「设置」，允许通知，提醒才会生效。
    </div>
  </div>
</body>
</html>
"@

# 用 .NET 写 UTF-8 且不带 BOM：BOM 出现在 <!DOCTYPE html> 之前可能触发怪异模式。
[System.IO.File]::WriteAllText(
    (Join-Path $shareDir 'index.html'),
    $html,
    (New-Object System.Text.UTF8Encoding($false))
)

Write-Host ''
Write-Host '==============================================================' -ForegroundColor DarkCyan
Write-Host '  手机下载地址（手机需与本机连同一个 Wi-Fi）' -ForegroundColor Cyan
Write-Host '==============================================================' -ForegroundColor DarkCyan
Write-Host ''
Write-Host "    http://${ip}:${Port}/" -ForegroundColor Green
Write-Host ''
Write-Host "  APK：$($apk.FullName)" -ForegroundColor Gray
Write-Host "  大小：$sizeMb MB   构建：$built" -ForegroundColor Gray
Write-Host ''
Write-Host '  按 Ctrl+C 停止共享。' -ForegroundColor DarkGray
Write-Host ''

$python = Join-Path $env:USERPROFILE '.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe'
if (-not (Test-Path $python)) { $python = 'python' }
& $python -m http.server $Port --bind 0.0.0.0 --directory $shareDir
