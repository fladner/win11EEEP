@echo off
rem Abre um agente paralelo na sessao atual do Administrador.
if not exist C:\ProgramData\EEEPBuild mkdir C:\ProgramData\EEEPBuild
copy /y "%~dp0Agente.ps1" C:\ProgramData\EEEPBuild\Agente2.ps1 >nul
start "EEEP par" /min powershell -NoProfile -ExecutionPolicy Bypass -File C:\ProgramData\EEEPBuild\Agente2.ps1 -Name par
