# Dropshipzone V7.1 自动更新脚本 (PowerShell版)
# 同时更新软件程序(main.js) + HTML(app.html) + V1.4服装鞋类 + 桌面文件
# 更新记录: 2026-06-21 修正V1.4文件名 + 新增全品类左侧导航版

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "===============================" -ForegroundColor Cyan
Write-Host " Dropshipzone V7.1 自动更新" -ForegroundColor Cyan
Write-Host " (软件程序 + HTML 同时更新)" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

# ========== 配置 ==========
$RAW_BASE = "https://raw.githubusercontent.com/luyao-CLOUD/dropshipzone-app/main/"
$INSTALL_DIR = "$env:LOCALAPPDATA\Programs\Dropshipzone V7.1"
$APP_DIR = "$INSTALL_DIR\resources\app"
$DESKTOP = [Environment]::GetFolderPath("Desktop")
$TEMP_DIR = "$env:TEMP\dropshipzone_update_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# 设置 TLS 1.2 (GitHub 要求)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 需要下载的文件列表
$CORE_FILES = @(
    @{ Name = "app.html";       Dest = "$APP_DIR\app.html";       Desc = "HTML应用" }
    @{ Name = "main.js";        Dest = "$APP_DIR\main.js";        Desc = "软件程序" }
    @{ Name = "package.json";   Dest = "$APP_DIR\package.json";   Desc = "包配置" }
    @{ Name = "version.json";   Dest = "$APP_DIR\version.json";   Desc = "版本信息" }
)
$DESKTOP_FILES = @(
    @{ Name = "app.html";                                           Dest = "$DESKTOP\Dropshipzone全品类上架模板_V7.1_左侧导航版.html"; Desc = "V7.1桌面版(全品类)" }
    @{ Name = "Dropshipzone服装鞋类上架工具_V1.4.html";             Dest = "$DESKTOP\Dropshipzone服装鞋类上架工具_V1.4.html";         Desc = "V1.4服装鞋类版" }
    @{ Name = "Dropshipzone全品类上架模板_v7.1.html";               Dest = "$DESKTOP\Dropshipzone全品类上架模板_v7.1.html";           Desc = "V7.1全品类版" }
    @{ Name = "Dropshipzone_批量上架模板_V7.1.xlsx";                Dest = "$DESKTOP\Dropshipzone_批量上架模板_V7.1.xlsx";            Desc = "Excel模板" }
)

# ===========================

# Step 1: 检查安装目录
Write-Host "[1/7] 检查安装目录..." -ForegroundColor Yellow
if (-not (Test-Path $INSTALL_DIR)) {
    Write-Host "  [!] 未找到安装目录: $INSTALL_DIR" -ForegroundColor Red
    Write-Host "  请确认已安装 V7.1 桌面应用" -ForegroundColor Gray
    Start-Sleep -Seconds 3
    exit 1
}
Write-Host "  [OK] 安装目录: $INSTALL_DIR" -ForegroundColor Green

# Step 2: 关闭正在运行的 V7.1
Write-Host "[2/7] 关闭正在运行的 V7.1..." -ForegroundColor Yellow
$processes = Get-Process -Name "Dropshipzone*" -ErrorAction SilentlyContinue
if ($processes) {
    $processes | ForEach-Object {
        Write-Host "  关闭: $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor DarkYellow
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
    Write-Host "  [OK] 已关闭" -ForegroundColor Green
} else {
    Write-Host "  [OK] 无运行中的进程" -ForegroundColor Green
}

# Step 3: 创建临时目录
Write-Host "[3/7] 准备下载..." -ForegroundColor Yellow
if (Test-Path $TEMP_DIR) { Remove-Item $TEMP_DIR -Recurse -Force }
New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null
Write-Host "  [OK] 临时目录就绪" -ForegroundColor Green

# Step 4: 下载所有文件
Write-Host "[4/7] 从 GitHub 下载文件..." -ForegroundColor Yellow
$downloadedFiles = @{}

# 下载核心文件
foreach ($file in $CORE_FILES) {
    $url = $RAW_BASE + $file.Name
    $tempFile = "$TEMP_DIR\$($file.Name)"
    try {
        Write-Host "  $($file.Desc) ($($file.Name))... " -NoNewline
        # 关键: -Proxy $null 绕过系统代理避免超时
        Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing -TimeoutSec 60 -Proxy $null
        $downloadedFiles[$file.Name] = $tempFile
        $size = [math]::Round((Get-Item $tempFile).Length / 1KB, 1)
        Write-Host "OK (${size}KB)" -ForegroundColor Green
    } catch {
        Write-Host "失败!" -ForegroundColor Red
        Write-Host "    错误: $($_.Exception.Message)" -ForegroundColor DarkRed
    }
}

# 下载桌面文件
foreach ($file in $DESKTOP_FILES) {
    $url = $RAW_BASE + $file.Name
    $tempFile = "$TEMP_DIR\$($file.Name)"
    try {
        Write-Host "  $($file.Desc) ($($file.Name))... " -NoNewline
        Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing -TimeoutSec 60 -Proxy $null
        $downloadedFiles[$file.Name] = $tempFile
        $size = [math]::Round((Get-Item $tempFile).Length / 1KB, 1)
        Write-Host "OK (${size}KB)" -ForegroundColor Green
    } catch {
        Write-Host "跳过" -ForegroundColor DarkYellow
    }
}

# 检查核心文件是否下载成功
if (-not $downloadedFiles.ContainsKey("app.html")) {
    Write-Host ""
    Write-Host "  [!] app.html 下载失败，无法更新" -ForegroundColor Red
    Write-Host "  可能原因: 网络连接问题或 GitHub 被墙" -ForegroundColor Gray
    Write-Host "  请检查网络后重试" -ForegroundColor Gray
    Remove-Item $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    exit 1
}

# Step 5: 更新安装目录文件
Write-Host "[5/7] 更新软件程序文件..." -ForegroundColor Yellow
foreach ($file in $CORE_FILES) {
    $tempFile = $downloadedFiles[$file.Name]
    if ($tempFile -and (Test-Path $tempFile)) {
        $destDir = Split-Path $file.Dest -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        
        # 备份旧文件
        if (Test-Path $file.Dest) {
            Copy-Item $file.Dest "$($file.Dest).bak" -Force
        }
        
        # 复制新文件
        Copy-Item $tempFile $file.Dest -Force
        Write-Host "  [OK] $($file.Desc) -> 已更新" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] $($file.Desc) (下载失败)" -ForegroundColor DarkYellow
    }
}

# Step 6: 更新桌面文件
Write-Host "[6/7] 更新桌面文件..." -ForegroundColor Yellow
foreach ($file in $DESKTOP_FILES) {
    $tempFile = $downloadedFiles[$file.Name]
    if ($tempFile -and (Test-Path $tempFile)) {
        Copy-Item $tempFile $file.Dest -Force
        Write-Host "  [OK] $($file.Desc) -> 已更新" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] $($file.Desc)" -ForegroundColor DarkYellow
    }
}

# Step 7: 清理并启动
Write-Host "[7/7] 清理临时文件..." -ForegroundColor Yellow
Remove-Item $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  [OK] 清理完成" -ForegroundColor Green

# 读取版本信息
$versionText = "v7.1"
if (Test-Path "$APP_DIR\version.json") {
    try {
        $verData = Get-Content "$APP_DIR\version.json" -Raw | ConvertFrom-Json
        $versionText = "v$($verData.version) ($($verData.updateDate))"
    } catch {}
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " [OK] 更新完成! 版本: $versionText" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host " 已更新文件:" -ForegroundColor White
Write-Host "   软件  main.js + package.json + version.json" -ForegroundColor Gray
Write-Host "   HTML  app.html" -ForegroundColor Gray
Write-Host "   桌面  V7.1全品类.html + V1.4服装鞋类.html + Excel模板" -ForegroundColor Gray
Write-Host ""
Write-Host " 安装目录: $INSTALL_DIR" -ForegroundColor DarkGray
Write-Host ""

# 启动 V7.1
$exePath = "$INSTALL_DIR\Dropshipzone V7.1.exe"
if (Test-Path $exePath) {
    Write-Host " 正在启动 V7.1..." -ForegroundColor Yellow
    Start-Process $exePath
    Write-Host " [OK] 已启动!" -ForegroundColor Green
} else {
    $exeFiles = Get-ChildItem "$INSTALL_DIR" -Filter "*.exe" -ErrorAction SilentlyContinue
    if ($exeFiles) {
        Write-Host " 正在启动 $($exeFiles[0].Name)..." -ForegroundColor Yellow
        Start-Process $exeFiles[0].FullName
        Write-Host " [OK] 已启动!" -ForegroundColor Green
    } else {
        Write-Host " [!] 未找到 exe，请手动启动" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host " 3秒后自动关闭..." -ForegroundColor DarkGray
Start-Sleep -Seconds 3
