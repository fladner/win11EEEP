Copy-Item D:\guest\Agente.ps1 C:\ProgramData\EEEPBuild\Agente.ps1 -Force
"agente atualizado: $((Get-Item C:\ProgramData\EEEPBuild\Agente.ps1).Length) bytes"
(Get-ScheduledTask EEEPBuild-* | Select-Object TaskName, State | Out-String).Trim()
shutdown.exe /r /t 15 /c "EEEP build: reinicio apos Windows Update"
'reinicio agendado em 15 s'
