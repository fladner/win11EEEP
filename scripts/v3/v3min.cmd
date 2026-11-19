@echo off
rem Chamado pelo autounattend (passo auditUser) com a letra do DVD como parametro.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %1:\v3min.ps1 -Dvd %1: > C:\v3min-console.log 2>&1
