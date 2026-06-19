@echo off
chcp 65001 > nul
echo ================================
echo  Dropshipzone GitHub 上传脚本
echo ================================
echo.

:: ========== 配置区 ==========
set REPO_URL=https://github.com/luyao-CLOUD/dropshipzone-app.git
set BRANCH=main
:: ================================

echo [1/4] 检查 git...
git --version > nul 2>&1
if errorlevel 1 (
    echo ❌ 未安装 git，请先安装：https://git-scm.com/
    pause & exit /b 1
)

echo [2/4] 准备文件...
set TMP_DIR=%TEMP%\dropshipzone_git_push
if exist "%TMP_DIR%" rmdir /s /q "%TMP_DIR%"
mkdir "%TMP_DIR%"

:: 复制 V7.1 安装文件（不含 node_modules 等）
xcopy "%LOCALAPPDATA%\Programs\Dropshipzone V7.1" "%TMP_DIR%\Dropshipzone V7.1\" /E /I /Y > nul

:: 复制 HTML 文件
copy "%USERPROFILE%\Desktop\Dropshipzone全品类上架模板_V7.1_翻译框可拖动版.html" "%TMP_DIR%\" > nul
copy "%USERPROFILE%\Desktop\Dropshipzone服装鞋类上架工具_V1.3_修复版.html" "%TMP_DIR%\" > nul

:: 复制 V1.3 完整 HTML（单文件版）
copy "%USERPROFILE%\Desktop\Dropshipzone服装鞋类上架工具_V1.3_修复版.html" "%TMP_DIR%\Dropshipzone V1.3.html" > nul

echo [3/4] 提交到 Git...
cd /d "%TMP_DIR%"
if not exist ".git" (
    git init
    git remote add origin "%REPO_URL%"
)
git add .
git commit -m "更新 v%date:~0,4%%date:~5,2%%date:~8,2% %time:~0,2%%time:~3,2%"

echo [4/4] 推送到 GitHub...
git push -u origin "%BRANCH%"

if errorlevel 1 (
    echo.
    echo ⚠️ 推送失败，可能需要先登录 GitHub。
    echo 请运行：git config --global credential.helper manager
    echo 然后重新运行此脚本。
    pause & exit /b 1
)

echo.
echo ✅ 上传完成！
echo 仓库地址：%REPO_URL%
echo.
pause
