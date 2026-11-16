@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$r = @(& '%~dp0Configure-LabUser.ps1' -Force); $r | Format-Table -AutoSize; Read-Host 'Pressione Enter para fechar'"
endlocal
