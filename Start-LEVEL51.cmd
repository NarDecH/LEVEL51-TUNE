@echo off
rem LEVEL51-TUNE :: ตัวเรียก GUI แบบ 1 คลิก (จะขึ้น UAC ให้เอง)
rem ต้องรันเป็น Administrator เพื่อให้ปุ่ม Apply/Restore ใช้ได้
setlocal
set "PS=powershell"
where pwsh >nul 2>nul && set "PS=pwsh"
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Level51Tune.Web.ps1" -Elevate
if errorlevel 1 pause
endlocal
