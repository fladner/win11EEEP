@echo off
rem Chamado pelo autounattend-full.xml (passo auditUser) com a letra do DVD como parametro.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %1:\v3full-inicio.ps1 -Dvd %1: > C:\v3full-console.log 2>&1
