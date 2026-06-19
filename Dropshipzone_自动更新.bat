@echo off
chcp 65001 > nul
echo ===============================
echo  Dropshipzone V7.1 自动更新脚本
echo  (同时更新软件程序 + HTML)
echo ===============================
echo.

:: ========== 配置区 ==========
set REPO_URL=https://github.com/luyao-CLOUD/dropshipzone-app
set ZIP_URL=%REPO_URL%/archive/refs/heads/main.zip
set INSTALL_DIR=%LOCALAPPDATA%\Programs\Dropshipzone V7.1
set APP_DIR=%INSTALL_DIR%\resources\app
set TEMP_ZIP=%TEMP%\dropshipzone_update.zip
set TEMP_DIR=%TEMP%\dropshipzone_update
:: ===============================

echo [1/8] 检查 PowerShell...
powershell -Command "Write-Host 'PowerShell OK'" > nul 2>&1
if errorlevel 1 (
    echo ❌ PowerShell 不可用，请使用 Windows 10 或更高版本
    pause & exit /b 1
)
echo ✅ PowerShell 可用

echo [2/8] 下载最新版本包...
powershell -Command "Invoke-WebRequest -Uri '%ZIP_URL%' -OutFile '%TEMP_ZIP%' -UseBasicParsing"
if not exist "%TEMP_ZIP%" (
    echo ❌ 下载失败，请检查网络连接
    echo    请确认能访问 github.com
    pause & exit /b 1
)
echo ✅ 下载完成

echo [3/8] 解压文件...
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%"
powershell -Command "Expand-Archive -Path '%TEMP_ZIP%' -DestinationPath '%TEMP_DIR%' -Force"
if errorlevel 1 (
    echo ❌ 解压失败
    pause & exit /b 1
)
echo ✅ 解压完成

echo [4/8] 查找解压后的目录...
for /f "delims=" %%i in ('dir "%TEMP_DIR%" /b /ad') do set EXTRACTED_DIR=%TEMP_DIR%\%%i
echo    解压目录: %EXTRACTED_DIR%

:: 确保安装目录存在
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
if not exist "%APP_DIR%" mkdir "%APP_DIR%"

echo [5/8] 更新软件程序文件 (main.js + package.json)...
:: ---- 更新 main.js ----
if exist "%EXTRACTED_DIR%\main.js" (
    copy "%EXTRACTED_DIR%\main.js" "%APP_DIR%\main.js" > nul
    echo ✅ main.js 已更新
) else (
    echo ⚠️ main.js 未找到，跳过
)

:: ---- 更新 package.json ----
if exist "%EXTRACTED_DIR%\package.json" (
    copy "%EXTRACTED_DIR%\package.json" "%APP_DIR%\package.json" > nul
    echo ✅ package.json 已更新
) else (
    echo ⚠️ package.json 未找到，跳过
)

:: ---- 更新 version.json ----
if exist "%EXTRACTED_DIR%\version.json" (
    copy "%EXTRACTED_DIR%\version.json" "%APP_DIR%\version.json" > nul
    echo ✅ version.json 已更新
) else (
    echo ⚠️ version.json 未找到，跳过
)

echo [6/8] 更新 HTML 应用文件 (app.html)...
:: ---- 优先使用 app.html ----
if exist "%EXTRACTED_DIR%\app.html" (
    copy "%EXTRACTED_DIR%\app.html" "%APP_DIR%\app.html" > nul
    echo ✅ app.html 已更新 (来自 app.html)
) else if exist "%EXTRACTED_DIR%\Dropshipzone全品类上架模板_v7.1.html" (
    :: 兼容旧文件名
    copy "%EXTRACTED_DIR%\Dropshipzone全品类上架模板_v7.1.html" "%APP_DIR%\app.html" > nul
    echo ✅ app.html 已更新 (来自 v7.1.html)
) else (
    echo ⚠️ HTML 文件未找到，跳过
)

echo [7/8] 更新桌面文件...
:: ---- V7.1 桌面版 ----
if exist "%EXTRACTED_DIR%\app.html" (
    copy "%EXTRACTED_DIR%\app.html" "%USERPROFILE%\Desktop\Dropshipzone全品类上架模板_V7.1.html" > nul
    echo ✅ V7.1 桌面版已更新
) else if exist "%EXTRACTED_DIR%\Dropshipzone全品类上架模板_v7.1.html" (
    copy "%EXTRACTED_DIR%\Dropshipzone全品类上架模板_v7.1.html" "%USERPROFILE%\Desktop\Dropshipzone全品类上架模板_V7.1.html" > nul
    echo ✅ V7.1 桌面版已更新
)

:: ---- V1.3 服装鞋类版 ----
if exist "%EXTRACTED_DIR%\Dropshipzone服装鞋类上架工具_V1.3.html" (
    copy "%EXTRACTED_DIR%\Dropshipzone服装鞋类上架工具_V1.3.html" "%USERPROFILE%\Desktop\Dropshipzone服装鞋类上架工具_V1.3.html" > nul
    echo ✅ V1.3 桌面版已更新
)

:: ---- Excel 模板 ----
if exist "%EXTRACTED_DIR%\Dropshipzone_批量上架模板_V7.1.xlsx" (
    copy "%EXTRACTED_DIR%\Dropshipzone_批量上架模板_V7.1.xlsx" "%USERPROFILE%\Desktop\Dropshipzone_批量上架模板_V7.1.xlsx" > nul
    echo ✅ Excel 模板已更新
)

echo [8/8] 清理临时文件...
del "%TEMP_ZIP%" /q 2>nul
rmdir /s /q "%TEMP_DIR%" 2>nul

echo.
echo ============================================
echo ✅ 更新完成！
echo.
echo 已更新文件:
echo   📦 软件程序: main.js + package.json + version.json
echo   🌐 HTML文件: app.html
echo   📄 桌面文件: V7.1.html + V1.3.html + Excel模板
echo.
echo 安装目录: %INSTALL_DIR%
echo.
echo 按任意键启动 V7.1...
pause > nul

:: 启动 V7.1
if exist "%INSTALL_DIR%\Dropshipzone V7.1.exe" (
    start "" "%INSTALL_DIR%\Dropshipzone V7.1.exe"
) else (
    echo ⚠️ 未找到 V7.1 可执行文件
    echo    请先安装 V7.1 桌面应用
    echo    或双击桌面上的 HTML 文件使用
    explorer "%USERPROFILE%\Desktop"
)
