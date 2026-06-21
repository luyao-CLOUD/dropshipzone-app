@echo off
chcp 65001 >nul 2>&1
title Dropzone Auto Update
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0auto-update.ps1"
pause
