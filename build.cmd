@echo off
REM Build script wrapper for Intune Backup Restore
REM This batch file provides a simple interface to the PowerShell build script

if "%1"=="" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" -Task Help
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" -Task %1
)

exit /b %ERRORLEVEL%
