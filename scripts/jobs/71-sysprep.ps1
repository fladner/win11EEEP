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
# identidade e senha do AnyDesk/RustDesk fora da imagem (decisao do usuario, 17/11); o primeiro boot repete a limpeza
Remove-Item 'C:\ProgramData\AnyDesk\service.conf*', 'C:\ProgramData\AnyDesk\system.conf*' -Force -ErrorAction SilentlyContinue
foreach ($c in @('C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config') + @(Get-ChildItem 'C:\Users\*\AppData\Roaming\RustDesk\config' -Directory -ErrorAction SilentlyContinue | ForEach-Object FullName)) {
    Remove-Item "$c\RustDesk.toml" -Force -ErrorAction SilentlyContinue
    if (Test-Path "$c\RustDesk2.toml") { $t = [IO.File]::ReadAllLines("$c\RustDesk2.toml") | Where-Object { $_ -notmatch '^\s*unlock_pin\s*=' }; [IO.File]::WriteAllLines("$c\RustDesk2.toml", [string[]]$t, (New-Object Text.UTF8Encoding $false)) }
}

# agentes de build fora da imagem
Unregister-ScheduledTask -TaskName 'EEEPBuild-user' -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName 'EEEPBuild-sys' -Confirm:$false -ErrorAction SilentlyContinue
# v3 do zero: no modo de auditoria o agente sobe pela chave Run (as tarefas ficam em "Queued")
Remove-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'EEEPBuild-sys', 'EEEPBuild-user' -ErrorAction SilentlyContinue
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
