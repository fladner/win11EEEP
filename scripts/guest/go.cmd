@echo off
rem Inicia a preparacao do build dentro da VM (pede elevacao/UAC).
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File %~dp0Instalar-Agente.ps1'"
