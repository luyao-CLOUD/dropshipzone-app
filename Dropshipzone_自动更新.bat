@echo off
chcp 65001 > nul
echo ===============================
echo  Dropshipzone 自动更新脚本（无需 Git）
echo ===============================
echo.

:: ========== 配置区 ==========
set REPO_URL=https://github.com/luyao-CLOUD/dropshipzone-app
set ZIP_URL=%REPO_URL%/archive/refs/heads/main.zip
set INSTALL_DIR=%LOCALAPPDATA%\Programs\Dropshipzone V7.1
set TEMP_ZIP=%TEMP%\dropshipzone_update.zip
set TEMP_DIR=%TEMP%\dropshipzone_update
:: ===============================

echo [1/6] 检查 PowerShell...
powershell -Command "Write-Host 'PowerShell 可用'" > nul 2>&1
if errorlevel 1 (
    echo ❌ PowerShell 不可用，请使用 Windows 10 或更高版本
    pause & exit /b 1
)
echo ✅ PowerShell 可用

echo [2/6] 下载最新版本...
powershell -Command "Invoke-WebRequest -Uri '%ZIP_URL%' -OutFile '%TEMP_ZIP%'"
if not exist "%TEMP_ZIP%" (
    echo ❌ 下载失败，请检查网络连接
    pause & exit /b 1
)
echo ✅ 下载完成

echo [3/6] 解压文件...
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%"
powershell -Command "Expand-Archive -Path '%TEMP_ZIP%' -DestinationPath '%TEMP_DIR%' -Force"
if errorlevel 1 (
    echo ❌ 解压失败
    pause & exit /b 1
)
echo ✅ 解压完成

echo [4/6] 查找解压后的目录...
:: GitHub ZIP 会创建一个带分支名的目录，找到它
for /f "delims=" %%i in ('dir "%TEMP_DIR%" /b /ad') do set EXTRACTED_DIR=%TEMP_DIR%\%%i
echo 解压目录: %EXTRACTED_DIR%

if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

echo [5/6] 安装更新...
:: 复制 V7.1 HTML 到安装目录
if exist "%EXTRACTED_DIR%\Dropshipzone全品类上架模板_v7.1.html" (
    if not exist "%INSTALL_DIR%\resources\app" mkdir "%INSTALL_DIR%\resources\app"
    copy "%EXTRACTED_DIR%\Dropshipzone全品类上架模板_v7.1.html" "%INSTALL_DIR%\resources\app\app.html" > nul
    echo ✅ 已更新 V7.1 应用文件
)

:: 复制 V1.3 HTML 到桌面
if exist "%EXTRACTED_DIR%\Dropshipzone服装鞋类上架工具_V1.3.html" (
    copy "%EXTRACTED_DIR%\Dropshipzone服装鞋类上架工具_V1.3.html" "%USERPROFILE%\Desktop\Dropshipzone服装鞋类上架工具_V1.3_修复版.html" > nul
    echo ✅ 已更新 V1.3 桌面版
)

:: 复制 V7.1 HTML 到桌面
if exist "%EXTRACTED_DIR%\Dropshipzone全品类上架模板_v7.1.html" (
    copy "%EXTRACTED_DIR%\Dropshipzone全品类上架模板_v7.1.html" "%USERPROFILE%\Desktop\Dropshipzone全品类上架模板_V7.1.html" > nul
    echo ✅ 已更新 V7.1 桌面版
)

echo [6/6] 清理临时文件...
del "%TEMP_ZIP%" /q 2>nul
rmdir /s /q "%TEMP_DIR%" 2>nul

echo.
echo ==================================
echo ✅ 更新完成！
echo 安装目录：%INSTALL_DIR%
echo 桌面文件已更新
echo.
echo 按任意键启动 V7.1...
pause > nul

:: 启动 V7.1
if exist "%INSTALL_DIR%\Dropshipzone V7.1.exe" (
    start "" "%INSTALL_DIR%\Dropshipzone V7.1.exe"
) else (
    echo ⚠️ 未找到 V7.1 可执行文件
    echo 请先安装 V7.1 桌面应用
    echo 或双击桌面上的 HTML 文件使用
    explorer "%USERPROFILE%\Desktop"
)
