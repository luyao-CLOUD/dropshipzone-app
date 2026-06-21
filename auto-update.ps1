# Dropzone Auto Update - Works on ANY machine (installed or NOT)
# Mode 1: If app installed -> updates all files + launches app
# Mode 2: If NOT installed -> downloads HTML files to desktop for browser use

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " Dropzone Auto Update" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Config
$RAW_BASE = "https://raw.githubusercontent.com/luyao-CLOUD/dropshipzone-app/main/"
$INSTALL_DIR = "$env:LOCALAPPDATA\Programs\Dropshipzone V7.1"
$APP_DIR = "$INSTALL_DIR\resources\app"
$DESKTOP = [Environment]::GetFolderPath("Desktop")
$TEMP_DIR = "$env:TEMP\dz_update_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Check if installed
$isInstalled = Test-Path $INSTALL_DIR

if ($isInstalled) {
    Write-Host "[1/6] App installed: $INSTALL_DIR" -ForegroundColor Green
    Write-Host "       Mode: Full Update (app + desktop files)" -ForegroundColor Gray
} else {
    Write-Host "[1/6] App NOT installed at $INSTALL_DIR" -ForegroundColor Yellow
    Write-Host "       Mode: Download Only (HTML files to Desktop)" -ForegroundColor Yellow
    Write-Host "       You can open them in browser directly!" -ForegroundColor Gray
}
Write-Host ""

# Kill running process (only if installed)
if ($isInstalled) {
    Write-Host "[2/6] Closing running app..." -ForegroundColor Yellow
    $procs = Get-Process -Name "Dropshipzone*" -ErrorAction SilentlyContinue
    if ($procs) {
        $procs | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 2
        Write-Host "  [OK] Done" -ForegroundColor Green
    } else { Write-Host "  [OK] No process running" -ForegroundColor Green }
}

# Prepare temp dir
Write-Host "[3/6] Preparing..." -ForegroundColor Yellow
if (Test-Path $TEMP_DIR) { Remove-Item $TEMP_DIR -Recurse -Force }
New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null

# Files to download from GitHub
$coreFiles = @(
    @{ Name="app.html";     Desc="V7.1 Main HTML (Core)" }
    @{ Name="main.js";      Desc="Main Program JS" }
    @{ Name="package.json"; Desc="Package Config" }
    @{ Name="version.json"; Desc="Version Info" }
)

$extraFiles = @(
    @{ Name="Dropshipzone服装鞋类上架工具_V1.4.html";             Desc="V1.4 Clothing/Shoes Tool" }
    @{ Name="Dropshipzone全品类上架模板_v7.1.html";               Desc="V7.1 Backup Version" }
    @{ Name="Dropshipzone_批量上架模板_V7.1.xlsx";                Desc="Excel Batch Template" }
)

# Download core files
Write-Host "[4/6] Downloading from GitHub..." -ForegroundColor Yellow
$dlFiles = @{}

foreach ($f in $coreFiles) {
    if (-not $isInstalled -and $f.Name -ne "app.html") { continue } # skip non-html if not installed
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

# Download extra files (desktop use)
foreach ($f in $extraFiles) {
    $url = $RAW_BASE + $f.Name
    $tmp = "$TEMP_DIR\$($f.Name)"
    try {
        Write-Host "  $($f.Desc)... " -NoNewline
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -TimeoutSec 60
        $dlFiles[$f.Name] = $tmp
        $sz = [math]::Round((Get-Item $tmp).Length / 1KB, 1)
        Write-Host "OK (${sz}KB)" -ForegroundColor Green
    } catch {
        Write-Host "SKIP" -ForegroundColor DarkYellow
    }
}

# Check critical file
if (-not $dlFiles.ContainsKey("app.html")) {
    Write-Host ""
    Write-Host "  [!] CRITICAL: Cannot download app.html!" -ForegroundColor Red
    Write-Host "  Check your internet / proxy settings." -ForegroundColor Gray
    Remove-Item $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    Read-Host "Press Enter to exit"
    exit 1
}

# Step 5: Copy files to destinations
Write-Host "[5/6] Installing files..." -ForegroundColor Yellow

if ($isInstalled) {
    # Update installed app files
    foreach ($f in $coreFiles) {
        $tmp = $dlFiles[$f.Name]
        if ($tmp -and (Test-Path $tmp)) {
            $dest = "$APP_DIR\$($f.Name)"
            if (Test-Path $dest) { Copy-Item $dest "$dest.bak" -Force }
            Copy-Item $tmp $dest -Force
            Write-Host "  [OK] $($f.Desc) -> App folder" -ForegroundColor Green
        }
    }
}

# Always copy to desktop
$deskMap = @{
    "app.html" = "Dropshipzone全品类上架模板_V7.1_左侧导航版.html"
    "Dropshipzone服装鞋类上架工具_V1.4.html" = "Dropshipzone服装鞋类上架工具_V1.4.html"
    "Dropshipzone全品类上架模板_v7.1.html" = "Dropshipzone全品类上架模板_v7.1.html"
    "Dropshipzone_批量上架模板_V7.1.xlsx" = "Dropshipzone_批量上架模板_V7.1.xlsx"
}

foreach ($key in $deskMap.Keys) {
    $tmp = $dlFiles[$key]
    if ($tmp -and (Test-Path $tmp)) {
        $destFile = $deskMap[$key]
        Copy-Item $tmp "$DESKTOP\$destFile" -Force
        Write-Host "  [OK] $destFile -> Desktop" -ForegroundColor Green
    }
}

# Cleanup
Write-Host "[6/6] Cleaning up..." -ForegroundColor Yellow
Remove-Item $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue

# Show version
$verText = "unknown"
$verPath = if ($isInstalled) { "$APP_DIR\version.json" } else { "$DESKTOP\Dropshipzone全品类上架模板_V7.1_左侧导航版.html.version" }
# Try to get version from downloaded data or just show success
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($isInstalled) {
    Write-Host " UPDATE COMPLETE!" -ForegroundColor Green
} else {
    Write-Host " DOWNLOAD COMPLETE!" -ForegroundColor Green
    Write-Host "" -ForegroundColor White
    Write-Host " Files saved to Desktop:" -ForegroundColor White
    Write-Host "   1. Double-click: Dropshipzone全品类上架模板_V7.1_左侧导航版.html" -ForegroundColor Cyan
    Write-Host "   2. Opens in browser, fully functional!" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor White
    Write-Host " Tip: For the best experience (desktop window," -ForegroundColor Gray
    Write-host "      ask admin for the V7.1 installer .exe file)" -ForegroundColor Gray
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host " Updated files:" -ForegroundColor White
Write-Host "  - V7.1 Full Category (Desktop)" -ForegroundColor Gray
Write-Host "  - V1.4 Clothing & Shoes (Desktop)" -ForegroundColor Gray
Write-Host "  - Excel Template (Desktop)" -ForegroundColor Gray
if ($isInstalled) {
    Write-Host "  - Core App files updated" -ForegroundColor Gray
}
Write-Host ""

# Launch
if ($isInstalled) {
    $exePath = "$INSTALL_DIR\Dropshipzone V7.1.exe"
    if (Test-Path $exePath) {
        Start-Process $exePath
        Write-Host " [OK] App launched!" -ForegroundColor Green
    } else {
        $exes = Get-ChildItem "$INSTALL_DIR" -Filter "*.exe" -ErrorAction SilentlyContinue
        if ($exes) { Start-Process $exes[0].FullName; Write-Host " [OK] Launched!" -ForegroundColor Green }
        else { Write-Host " [!] No exe found, start manually" -ForegroundColor Red }
    }
} else {
    # Open the main HTML in default browser
    $htmlPath = "$DESKTOP\Dropshipzone全品类上架模板_V7.1_左侧导航版.html"
    if (Test-Path $htmlPath) {
        Write-Host " Opening V7.1 in browser..." -ForegroundColor Yellow
        Start-Process $htmlPath
        Write-Host " [OK] Opened!" -ForegroundColor Green
    }
}

Write-Host ""
Read-Host "Press Enter to exit"
