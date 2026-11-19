# v3 do zero, passo 9: prepara a generalizacao (roda como SYSTEM, depois do 60-limpeza e antes do 71-sysprep).
# Scripts de primeiro boot vem da midia EEEPFINAL (build\final.viso, pasta guest).
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\v3-preparar.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
$d = (Get-CimInstance Win32_LogicalDisk | Where-Object VolumeName -eq 'EEEPFINAL').DeviceID
if (-not $d) { L 'FALHA: midia EEEPFINAL nao encontrada'; exit 1 }
$g = "$d\guest"

# Windows Update volta ao normal (a politica so servia para o build)
Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name NoAutoUpdate -ErrorAction SilentlyContinue
L "NoAutoUpdate removido: $($null -eq (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -ErrorAction SilentlyContinue).NoAutoUpdate)"

# scripts de primeiro boot e arquivo de resposta
New-Item -ItemType Directory -Force C:\Windows\Setup\Scripts | Out-Null
Copy-Item "$g\EEEP-PrimeiroBoot.ps1", "$g\SetupComplete.cmd", "$g\EEEP-CorrigirPerfis.ps1" C:\Windows\Setup\Scripts -Force
$tz = (Get-TimeZone).Id
$x = [IO.File]::ReadAllText("$g\unattend-sysprep.xml") -replace '<TimeZone>[^<]*</TimeZone>', "<TimeZone>$tz</TimeZone>"
try { [void][xml]$x; L 'unattend: XML valido' } catch { L "FALHA: unattend invalido $($_.Exception.Message)" }
[IO.File]::WriteAllText('C:\Windows\System32\Sysprep\eeep-unattend.xml', $x, (New-Object Text.UTF8Encoding $false))
L ("Setup\Scripts: " + ((Get-ChildItem C:\Windows\Setup\Scripts -File | ForEach-Object Name) -join ', ') + " | unattend: $(Test-Path C:\Windows\System32\Sysprep\eeep-unattend.xml) | fuso: $tz")

# DNS automatico
Get-NetAdapter | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue }

# WinRE volta para dentro do Windows para ir junto na captura
& reagentc.exe /disable 2>&1 | ForEach-Object { L "  reagentc: $_" }
L "Winre.wim em System32\Recovery: $(Test-Path C:\Windows\System32\Recovery\Winre.wim)"

# Windows.old e pastas de upgrade fazem o instalador do 26H2 falhar (CRelocateOS 0x800700B7)
foreach ($p in 'C:\Windows.old', 'C:\$WINDOWS.~BT', 'C:\$Windows.~WS') {
    if (Test-Path -LiteralPath $p) { & takeown.exe /f $p /r /d s 2>&1 | Out-Null; & icacls.exe $p /grant 'Administradores:F' /t /c /q 2>&1 | Out-Null; Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue }
    L "$p existe: $(Test-Path -LiteralPath $p)"
}

# pacotes da Store instalados so para usuarios (bloqueiam o sysprep)
$prov = @((Get-AppxProvisionedPackage -Online).DisplayName)
$bad = Get-AppxPackage -AllUsers | Where-Object { -not $_.IsFramework -and $_.SignatureKind -ne 'System' -and -not $_.NonRemovable -and ($prov -notcontains $_.Name) }
foreach ($p in $bad) {
    try { Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop; L "  appx removido: $($p.Name)" } catch { L "  appx NAO removido: $($p.Name) -> $($_.Exception.Message.Split([char]10)[0])" }
}

# energia: nunca suspender/hibernar; tela apaga apos 15 minutos (repetido no EEEP-PrimeiroBoot)
& powercfg.exe /h off 2>&1 | Out-Null
foreach ($m in 'ac', 'dc') {
    & powercfg.exe /change "standby-timeout-$m" 0; & powercfg.exe /change "hibernate-timeout-$m" 0; & powercfg.exe /change "monitor-timeout-$m" 15
}
L ("energia: " + ((& powercfg.exe /q SCHEME_CURRENT SUB_VIDEO VIDEOIDLE | Select-String 'Atual|Current') -join ' ') + " | hibernacao: $(-not (Test-Path C:\hiberfil.sys))")

# lancador dos agentes do build
Remove-Item C:\a.cmd -Force -ErrorAction SilentlyContinue
L ("contas: " + ((Get-LocalUser | Where-Object { $_.Name -in 'Administrador', 'Aluno' } | ForEach-Object { "$($_.Name) ativo=$($_.Enabled) senha=$($_.PasswordLastSet)" }) -join ' | '))
L ("BitLocker C: $((Get-BitLockerVolume C: -ErrorAction SilentlyContinue).VolumeStatus)  reinicio pendente: $(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')")
L 'fim v3-preparar'
