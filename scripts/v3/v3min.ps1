# v3 minima (26H2 limpo, sem programas): roda no modo de auditoria como o Administrador interno.
# Cria as contas, aplica a configuracao EEEP de primeiro boot e generaliza com o mesmo unattend da v1/v2.
# Diferencas propositais em relacao as builds 26H2 que entraram em looping: instalacao limpa (sem upgrade de
# versao) e WinRE original da propria imagem (reagentc /disable devolve o Winre.wim para System32\Recovery).
param([string]$Dvd = 'D:')
$ErrorActionPreference = 'Continue'
$log = 'C:\v3min.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 's'), $m; Add-Content $log $l; $l }
L "inicio  build $([Environment]::OSVersion.Version)  UBR $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR)"
$g = Join-Path $Dvd 'guest'

# contas (TESTE: sem senha; na v3 completa o usuario define as senhas na VM)
& net.exe user Aluno /add /fullname:Aluno /passwordchg:yes 2>&1 | Out-Null
& net.exe user CREDE /add /fullname:CREDE 2>&1 | Out-Null
& net.exe user CREDE /active:no 2>&1 | Out-Null
& net.exe user Administrador /active:yes 2>&1 | Out-Null
L ("contas: " + ((Get-LocalUser | ForEach-Object { "$($_.Name)=$($_.Enabled)" }) -join ' '))

# avisos de OOBE, conta Microsoft, OneDrive
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $g 'Desativar-AvisosOOBE.ps1') 2>&1 | ForEach-Object { L "  avisos: $_" }

# diagnostico: tela azul fica na tela (com o codigo) em vez de reiniciar sozinho
& reg.exe add HKLM\SYSTEM\CurrentControlSet\Control\CrashControl /v AutoReboot /t REG_DWORD /d 0 /f | Out-Null
L 'CrashControl AutoReboot=0'

# scripts de primeiro boot e arquivo de resposta do sysprep (iguais aos da v1/v2)
New-Item -ItemType Directory -Force C:\Windows\Setup\Scripts | Out-Null
Copy-Item (Join-Path $g 'EEEP-PrimeiroBoot.ps1'), (Join-Path $g 'SetupComplete.cmd') C:\Windows\Setup\Scripts -Force
Copy-Item (Join-Path $g 'unattend-sysprep.xml') C:\Windows\System32\Sysprep\eeep-unattend.xml -Force
$ps = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$a = New-ScheduledTaskAction -Execute $ps -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\Windows\Setup\Scripts\EEEP-PrimeiroBoot.ps1'
Register-ScheduledTask -TaskName 'EEEP-PrimeiroBoot' -Action $a -Trigger (New-ScheduledTaskTrigger -AtStartup) -Principal (New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest) -Force | Out-Null
L "arquivos: $(Test-Path C:\Windows\Setup\Scripts\EEEP-PrimeiroBoot.ps1) $(Test-Path C:\Windows\Setup\Scripts\SetupComplete.cmd) $(Test-Path C:\Windows\System32\Sysprep\eeep-unattend.xml)"

# WinRE: volta para dentro do Windows para ir junto na captura
& reagentc.exe /disable 2>&1 | ForEach-Object { L "  reagentc: $_" }
L "Winre.wim em System32\Recovery: $(Test-Path C:\Windows\System32\Recovery\Winre.wim)"

# BitLocker / criptografia do dispositivo
L ("BitLocker: " + ((& manage-bde.exe -status C: 2>&1 | Select-String 'Status da Convers|Conversion Status|Prote') -join ' | '))

# Windows.old na imagem faz o instalador do 26H2 falhar (CRelocateOS 0x800700B7) e o PC reiniciar em looping
foreach ($d in 'C:\Windows.old', 'C:\$WINDOWS.~BT', 'C:\$Windows.~WS') {
    if (Test-Path -LiteralPath $d) { & takeown.exe /f $d /r /d s 2>&1 | Out-Null; & icacls.exe $d /grant 'Administradores:F' /t /c /q 2>&1 | Out-Null; Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
    L "$d ainda existe: $(Test-Path -LiteralPath $d)"
}

# sysprep (fecha a janela do sysprep que o modo de auditoria abre sozinho)
Get-Process sysprep -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 3
Remove-Item C:\Windows\System32\Sysprep\Panther -Recurse -Force -ErrorAction SilentlyContinue
L 'sysprep /generalize /oobe /shutdown'
$p = Start-Process C:\Windows\System32\Sysprep\sysprep.exe -ArgumentList '/generalize', '/oobe', '/shutdown', '/quiet', '/unattend:C:\Windows\System32\Sysprep\eeep-unattend.xml' -PassThru
$p.WaitForExit()
Start-Sleep 20
L "SYSPREP NAO DESLIGOU: exit=$($p.ExitCode)"
Get-Content C:\Windows\System32\Sysprep\Panther\setuperr.log -ErrorAction SilentlyContinue | Select-Object -Last 20 | ForEach-Object { L "  $_" }
