# v3 completa do zero: primeiro passo no modo de auditoria (Administrador interno), chamado pelo autounattend-full.xml.
# Igual ao inicio do v3min.ps1 (que funcionou no notebook), mas SEM sysprep: instala o agente de build para os
# programas entrarem pelo ROTEIRO-V3.md. As senhas das contas o usuario define depois, na VM.
param([string]$Dvd = 'D:')
$ErrorActionPreference = 'Continue'
$log = 'C:\v3full-inicio.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 's'), $m; Add-Content $log $l; $l }
L "inicio  build $([Environment]::OSVersion.Version)  UBR $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR)"
$g = Join-Path $Dvd 'guest'

# contas
# (sem a conta CREDE: pedido do usuario em 18/11)
& net.exe user Aluno /add /fullname:Aluno /passwordchg:yes 2>&1 | Out-Null
& net.exe user Administrador /active:yes 2>&1 | Out-Null
L ("contas: " + ((Get-LocalUser | ForEach-Object { "$($_.Name)=$($_.Enabled)" }) -join ' '))

# avisos de OOBE, conta Microsoft, OneDrive
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $g 'Desativar-AvisosOOBE.ps1') 2>&1 | ForEach-Object { L "  avisos: $_" }

# tela azul fica na tela (com o codigo) em vez de reiniciar sozinho
& reg.exe add HKLM\SYSTEM\CurrentControlSet\Control\CrashControl /v AutoReboot /t REG_DWORD /d 0 /f | Out-Null

# durante a montagem o build fica no 26300.9457 (o mesmo da v3min, que inicia no notebook):
# Windows Update automatico desligado ATE O PASSO 9 do roteiro (70-preparar-sysprep remove esta politica)
& reg.exe add HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU /v NoAutoUpdate /t REG_DWORD /d 1 /f | Out-Null
L 'Windows Update automatico desligado durante a montagem'

# agente de build (tarefas EEEPBuild-sys e EEEPBuild-user), igual ao Instalar-Agente.ps1
$dst = 'C:\ProgramData\EEEPBuild'; New-Item -ItemType Directory -Force $dst | Out-Null
Copy-Item (Join-Path $g 'Agente.ps1') $dst -Force
$ps = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
$aSys = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $dst\Agente.ps1 -Name sys"
Register-ScheduledTask -TaskName 'EEEPBuild-sys' -Action $aSys -Trigger (New-ScheduledTaskTrigger -AtStartup) -Principal (New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest) -Settings $set -Force | Out-Null
$me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$aUsr = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $dst\Agente.ps1 -Name user"
Register-ScheduledTask -TaskName 'EEEPBuild-user' -Action $aUsr -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $me) -Principal (New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive -RunLevel Highest) -Settings $set -Force | Out-Null
Start-ScheduledTask -TaskName 'EEEPBuild-sys'
# no modo de auditoria o Agendador deixa as tarefas acima em "Queued" (nao executam): o agente tambem sobe pela
# chave Run (logon automatico do Administrador no modo de auditoria). 71-sysprep remove estas entradas.
foreach ($n in 'sys', 'user') {
    Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name "EEEPBuild-$n" -Value "`"$ps`" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $dst\Agente.ps1 -Name $n"
}
L "agente instalado (usuario: $me)"
L 'fim'
