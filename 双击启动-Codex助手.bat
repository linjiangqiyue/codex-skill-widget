@echo off
cd /d "%~dp0"
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Start-CodexSkillWidget.ps1"
