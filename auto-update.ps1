# Dropshipzone V7.1 Auto Update (PowerShell)
# Download latest files from GitHub
# Fixed: pure ASCII, no Chinese characters, works on all Windows machines

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " Dropzone V7.1 Auto Update" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

$RAW_BASE = "https://raw.githubusercontent.com/luyao-CLOUD/dropshipzone-app/main/"
$INSTALL_DIR = "$env:LOCALAPPDATA\Programs\Dropshipzone V7.1"
$APP_DIR = "$INSTALL_DIR\resources\app"
$DESKTOP = [Environment]::GetFolderPath("Desktop")
$TEMP_DIR = "$env:TEMP\dz_update_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Step 1: Check install directory
Write-Host "[1/6] Checking install dir..." -ForegroundColor Yellow
if (-not (Test-Path $INSTALL_DIR)) {
    Write-Host "  [!] Install dir NOT found: $INSTALL_DIR" -ForegroundColor Red
    Write-Host "  Please install Dropzone V7.1 first!" -ForegroundColor Gray
    Start-Sleep -Seconds 5
    exit 1
}
Write-Host "  [OK] Found: $INSTALL_DIR" -ForegroundColor Green

# Step 2: Kill running process
Write-Host "[2/6] Closing running app..." -ForegroundColor Yellow
$procs = Get-Process -Name "Dropshipzone*" -ErrorAction SilentlyContinue
if ($procs) {
    $procs | ForEach-Object {
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        Write-Host "  Stopped: $($_.ProcessName)" -ForegroundColor DarkYellow
    }
    Start-Sleep -Seconds 2
} else {
    Write-Host "  [OK] No running process" -ForegroundColor Green
}

# Step 3: Prepare temp dir
Write-Host "[3/6] Preparing..." -ForegroundColor Yellow
if (Test-Path $TEMP_DIR) { Remove-Item $TEMP_DIR -Recurse -Force }
New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null

# Files to download
$coreFiles = @(
    @{ Name="app.html";     Dest="$APP_DIR\app.html";       Desc="HTML Core" },
    @{ Name="main.js";      Dest="$APP_DIR\main.js";        Desc="Main Program" },
    @{ Name="package.json"; Dest="$APP_DIR\package.json";   Desc="Package Config" },
    @{ Name="version.json"; Dest="$APP_DIR\version.json";   Desc="Version Info" }
)

$deskFiles = @(
    @{ Name="app.html";                                           Desc="V7.1 Full Category" },
    @{ Name="Dropshipzone服装鞋类上架工具_V1.4.html";              Desc="V1.4 Clothing & Shoes" },
    @{ Name="Dropshipzone全品类上架模板_v7.1.html";                Desc="V7.1 Backup" },
    @{ Name="Dropshipzone_批量上架模板_V7.1.xlsx";                 Desc="Excel Template" }
)

# Step 4: Download from GitHub
Write-Host "[4/6] Downloading from GitHub..." -ForegroundColor Yellow
$dlFiles = @{}

foreach ($f in $coreFiles) {
    $url = $RAW_BASE + $f.Name
    $tmp = "$TEMP_DIR\$($f.Name)"
    try {
        Write-Host "  $($f.Desc)... " -NoNewline
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -TimeoutSec 120
        $dlFiles[$f.Name] = $tmp
        $sz = [math]::Round((Get-Item $tmp).Length / 1KB, 1)
        Write-Host "OK (${sz}KB)" -ForegroundColor Green
    } catch {
        Write-Host "FAILED" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor DarkRed
    }
}

foreach ($f in $deskFiles) {
    $url = $RAW_BASE + $f.Name
    $tmp = "$TEMP_DIR\$($f.Name)"
    try {
        Write-Host "  $($f.Desc)... " -NoNewline
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -TimeoutSec 60
        $dlFiles[$f.Name] = $tmp
        $sz = [math]::Round((Get-Item $tmp).Length / 1KB, 1)
        Write-Host "OK (${sz}KB)" -ForegroundColor Green
    } catch {
        Write-Host "SKIP (file not found on GitHub)" -ForegroundColor DarkYellow
    }
}

if (-not $dlFiles.ContainsKey("app.html")) {
    Write-Host ""
    Write-Host "  [!] CRITICAL: app.html download FAILED!" -ForegroundColor Red
    Write-Host "  Possible causes:" -ForegroundColor Gray
    Write-Host "    1. No internet connection or GitHub blocked" -ForegroundColor Gray
    Write-Host "    2. Need VPN/proxy to access GitHub" -ForegroundColor Gray
    Remove-Item $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    Read-Host "Press Enter to exit"
    exit 1
}

# Step 5: Update files
Write-Host "[5/6] Updating files..." -ForegroundColor Yellow
foreach ($f in $coreFiles) {
    $tmp = $dlFiles[$f.Name]
    if ($tmp -and (Test-Path $tmp)) {
        if (Test-Path $f.Dest) { Copy-Item $f.Dest "$($f.Dest).bak" -Force }
        Copy-Item $tmp $f.Dest -Force
        Write-Host "  [OK] $($f.Desc) updated" -ForegroundColor Green
    }
}

# Desktop file mapping for download -> desktop destination
$deskDestMap = @{
    "app.html" = "Dropshipzone全品类上架模板_V7.1_左侧导航版.html"
    "Dropshipzone服装鞋类上架工具_V1.4.html" = "Dropshipzone服装鞋类上架工具_V1.4.html"
    "Dropshipzone全品类上架模板_v7.1.html" = "Dropshipzone全品类上架模板_v7.1.html"
    "Dropshipzone_批量上架模板_V7.1.xlsx" = "Dropshipzone_批量上架模板_V7.1.xlsx"
}

foreach ($f in $deskFiles) {
    $tmp = $dlFiles[$f.Name]
    if ($tmp -and (Test-Path $tmp)) {
        $destFile = $deskDestMap[$f.Name]
        if ($destFile) {
            Copy-Item $tmp "$DESKTOP\$destFile" -Force
            Write-Host "  [OK] $($f.Desc) -> Desktop" -ForegroundColor Green
        }
    }
}

# Step 6: Cleanup & launch
Write-Host "[6/6] Cleaning up..." -ForegroundColor Yellow
Remove-Item $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue

$verText = "unknown"
if (Test-Path "$APP_DIR\version.json") {
    try {
        $v = Get-Content "$APP_DIR\version.json" -Raw | ConvertFrom-Json
        $verText = "V$($v.version) ($($v.updateDate))"
    } catch {}
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " DONE! Version: $verText" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host " Updated:" -ForegroundColor White
Write-Host "  Core: app.html + main.js + version.json" -ForegroundColor Gray
Write-Host "  Desk: V7.1 + V1.4 + Excel template" -ForegroundColor Gray
Write-Host ""

$exePath = "$INSTALL_DIR\Dropshipzone V7.1.exe"
if (Test-Path $exePath) {
    Write-Host " Starting Dropzone V7.1..." -ForegroundColor Yellow
    Start-Process $exePath
    Write-Host " [OK] Launched!" -ForegroundColor Green
} else {
    $exes = Get-ChildItem "$INSTALL_DIR" -Filter "*.exe" -ErrorAction SilentlyContinue
    if ($exes) {
        Start-Process $exes[0].FullName
        Write-Host " [OK] Launched $($exes[0].Name)!" -ForegroundColor Green
    } else {
        Write-Host " [!] exe not found, please start manually" -ForegroundColor Red
    }
}
Write-Host ""
Read-Host "Press Enter to exit"
