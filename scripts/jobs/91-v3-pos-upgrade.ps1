# v3: depois do upgrade 23H2 -> 26H2 da VM EEEP-2025 (agente sys). Prepara a imagem para o sysprep.
#  1. Windows.old / $WINDOWS.~BT / $Windows.~WS fora (com Windows.old na imagem o instalador do 26H2 falha com
#     CRelocateOS 0x800700B7 e o PC reinicia em looping)
#  2. chave HKLM\SYSTEM\Setup\Upgrade fora (o sysprep recusa Windows atualizado por cima)
#  3. WinRE de volta para C:\Windows\System32\Recovery (vai junto na captura)
#  4. avisos de OOBE/conta Microsoft/OneDrive de novo (o upgrade pode ter reativado)
#  5. regras do Aluno + papel de parede (scripts\v3\Aplicar-GPO-Papel.ps1)
#  6. unidade do kit como D: (os jobs 70/71 usam D:\guest)
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\v3.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
$v = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
L "Windows $($v.DisplayVersion) $($v.CurrentBuild).$($v.UBR)"

# 6. kit em D:
$kit = Get-CimInstance Win32_Volume | Where-Object Label -eq 'EEEPKIT'
if ($kit -and $kit.DriveLetter -ne 'D:') {
    $d = Get-CimInstance Win32_Volume | Where-Object DriveLetter -eq 'D:'
    if ($d) { $d | Set-CimInstance -Property @{ DriveLetter = $null } }
    $kit | Set-CimInstance -Property @{ DriveLetter = 'D:' }
}
L "kit em: $((Get-CimInstance Win32_Volume | Where-Object Label -eq 'EEEPKIT').DriveLetter)  D:\guest=$(Test-Path D:\guest)  D:\v3=$(Test-Path D:\v3)"

# 1. pastas do upgrade
foreach ($p in 'C:\Windows.old', 'C:\$WINDOWS.~BT', 'C:\$Windows.~WS', 'C:\$WinREAgent') {
    if (Test-Path -LiteralPath $p) {
        & takeown.exe /f $p /r /d s 2>&1 | Out-Null
        & icacls.exe $p /grant '*S-1-5-32-544:F' /t /c /q 2>&1 | Out-Null
        & cmd.exe /c "rd /s /q `"$p`"" 2>&1 | Out-Null
    }
    L "$p ainda existe: $(Test-Path -LiteralPath $p)"
}

# 2. bloqueio do sysprep em Windows atualizado
Remove-Item HKLM:\SYSTEM\Setup\Upgrade -Recurse -Force -ErrorAction SilentlyContinue
L "chave Setup\Upgrade: $(Test-Path HKLM:\SYSTEM\Setup\Upgrade)"

# 3. WinRE
& reagentc.exe /info 2>&1 | Where-Object { $_ -match 'Status|Local|Location' } | ForEach-Object { L "  reagentc: $_" }
& reagentc.exe /disable 2>&1 | ForEach-Object { L "  reagentc /disable: $_" }
L "Winre.wim em System32\Recovery: $(Test-Path C:\Windows\System32\Recovery\Winre.wim)"

# 4. avisos
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\guest\Desativar-AvisosOOBE.ps1 2>&1 | ForEach-Object { L "  avisos: $_" }

# 5. regras do Aluno e papel de parede
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\v3\Aplicar-GPO-Papel.ps1 2>&1 | ForEach-Object { L "  gpo: $_" }

L ("C: livre {0:N1} GB" -f ((Get-Volume C).SizeRemaining / 1GB))
L "reinicio pendente: $(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')"
