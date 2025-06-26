@echo off
REM Запуск PowerShell скрипта с обходом политики выполнения

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SetLockscreen.ps1"

pause