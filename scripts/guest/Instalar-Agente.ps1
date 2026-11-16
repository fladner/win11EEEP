#Requires -RunAsAdministrator
# Copia o agente para a VM e registra duas tarefas agendadas temporarias:
#   EEEPBuild-sys  : como SYSTEM, na inicializacao
#   EEEPBuild-user : como o usuario atual (elevado), no logon
$ErrorActionPreference = 'Stop'
$dst = 'C:\ProgramData\EEEPBuild'; New-Item -ItemType Directory -Force $dst | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'Agente.ps1') $dst -Force
$ps = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew

$aSys = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $dst\Agente.ps1 -Name sys"
Register-ScheduledTask -TaskName 'EEEPBuild-sys' -Action $aSys -Trigger (New-ScheduledTaskTrigger -AtStartup) -Principal (New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest) -Settings $set -Force | Out-Null

$me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$aUsr = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $dst\Agente.ps1 -Name user"
Register-ScheduledTask -TaskName 'EEEPBuild-user' -Action $aUsr -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $me) -Principal (New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive -RunLevel Highest) -Settings $set -Force | Out-Null

Start-ScheduledTask -TaskName 'EEEPBuild-sys'
Start-ScheduledTask -TaskName 'EEEPBuild-user'
Write-Host "Agente de build instalado para $me. Pode fechar esta janela." -ForegroundColor Green
Start-Sleep 5
