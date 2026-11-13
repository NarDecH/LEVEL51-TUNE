@echo off
rem LEVEL51-TUNE :: ตัวเรียก tray icon 1 คลิก
rem ไม่ต้องรันเป็น Administrator — เมนูที่แก้ระบบจะขอ UAC เองทีละครั้ง
rem ส่ง argument ต่อได้ เช่น  Start-LEVEL51-Tray.cmd -Port 8899
setlocal
set "PS=powershell"
where pwsh >nul 2>nul && set "PS=pwsh"
start "" "%PS%" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Level51Tune.Tray.ps1" %*
if errorlevel 1 pause
endlocal
