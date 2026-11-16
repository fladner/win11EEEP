# Passo final dentro da VM: remove os agentes de build, registra a tarefa-reserva de primeiro boot e executa
# sysprep /generalize /oobe /shutdown. Se o sysprep falhar, restaura o agente de sistema e relata o erro.
$ErrorActionPreference = 'Continue'
$w = 'C:\ProgramData\EEEPBuild'
$ps = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
# tarefa-reserva: roda o script de primeiro boot na inicializacao (ele se remove ao concluir)
$a = New-ScheduledTaskAction -Execute $ps -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\Windows\Setup\Scripts\EEEP-PrimeiroBoot.ps1'
Register-ScheduledTask -TaskName 'EEEP-PrimeiroBoot' -Action $a -Trigger (New-ScheduledTaskTrigger -AtStartup) -Principal (New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest) -Force | Out-Null
Remove-Item 'HKLM:\SOFTWARE\EEEP' -Recurse -Force -ErrorAction SilentlyContinue

Stop-Service AnyDesk, RustDesk -Force -ErrorAction SilentlyContinue
Get-Process AnyDesk, rustdesk, netmonitor-agent, OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Remove-Item 'C:\ProgramData\AnyDesk\service.conf' -Force -ErrorAction SilentlyContinue

# agentes de build fora da imagem
Unregister-ScheduledTask -TaskName 'EEEPBuild-user' -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName 'EEEPBuild-sys' -Confirm:$false -ErrorAction SilentlyContinue
Get-ChildItem $w -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -ne $PSCommandPath -and $_.Name -ne 'Agente.ps1' } | Remove-Item -Force -ErrorAction SilentlyContinue
& cmd.exe /c "schtasks /create /tn EEEP-LimpaBuild /sc onstart /ru SYSTEM /f /tr `"cmd /c rd /s /q C:\ProgramData\EEEPBuild & schtasks /delete /tn EEEP-LimpaBuild /f`"" | Out-Null

Remove-Item C:\Windows\System32\Sysprep\Panther -Recurse -Force -ErrorAction SilentlyContinue
$p = Start-Process C:\Windows\System32\Sysprep\sysprep.exe -ArgumentList '/generalize', '/oobe', '/shutdown', '/quiet', '/unattend:C:\Windows\System32\Sysprep\eeep-unattend.xml' -PassThru
$p.WaitForExit()
# so chega aqui se o sysprep NAO desligou a maquina (falha)
Start-Sleep 20
"sysprep terminou sem desligar: exit=$($p.ExitCode)"
Get-Content C:\Windows\System32\Sysprep\Panther\setuperr.log -ErrorAction SilentlyContinue | Select-Object -Last 15 | ForEach-Object { $_.Substring(0, [math]::Min(260, $_.Length)) }
"estado da imagem: $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State').ImageState)"
# restaura o agente de sistema para permitir nova tentativa
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName 'EEEPBuild-sys' -Action (New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $w\Agente.ps1 -Name sys") -Trigger (New-ScheduledTaskTrigger -AtStartup) -Principal (New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest) -Settings $set -Force | Out-Null
schtasks /delete /tn EEEP-LimpaBuild /f | Out-Null
'agente de sistema restaurado'
