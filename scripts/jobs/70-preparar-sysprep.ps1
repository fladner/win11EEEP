# Prepara a generalizacao: instala o script de primeiro boot e o arquivo de resposta, testa a limpeza do
# RustDesk numa copia e remove pacotes da Store que impedem o sysprep (instalados so para um usuario).
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force C:\Windows\Setup\Scripts | Out-Null
Copy-Item D:\guest\EEEP-PrimeiroBoot.ps1 C:\Windows\Setup\Scripts\EEEP-PrimeiroBoot.ps1 -Force
# reserva contra o OOBE preso na conta defaultuser0 (ver unattend: SkipMachineOOBE/SkipUserOOBE)
Copy-Item D:\guest\SetupComplete.cmd C:\Windows\Setup\Scripts\SetupComplete.cmd -Force
"SetupComplete.cmd: $(Test-Path C:\Windows\Setup\Scripts\SetupComplete.cmd)"
# DNS fixo usado durante o build volta para o automatico (DHCP) antes de generalizar
Get-NetAdapter | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue }
'DNS: ' + ((Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object ServerAddresses | ForEach-Object { "$($_.InterfaceAlias)=$($_.ServerAddresses -join ',')" }) -join ' ')
$tz = (Get-TimeZone).Id
$x = [IO.File]::ReadAllText('D:\guest\unattend-sysprep.xml') -replace '<TimeZone>[^<]*</TimeZone>', "<TimeZone>$tz</TimeZone>"
[IO.File]::WriteAllText('C:\Windows\System32\Sysprep\eeep-unattend.xml', $x, (New-Object Text.UTF8Encoding $false))
"fuso horario: $tz ; arquivos: $(Test-Path C:\Windows\Setup\Scripts\EEEP-PrimeiroBoot.ps1) $(Test-Path C:\Windows\System32\Sysprep\eeep-unattend.xml)"
try { [void][xml]$x; 'unattend: XML valido' } catch { "unattend: XML INVALIDO $($_.Exception.Message)" }

'--- RustDesk.toml (chaves antes):'
$toml = 'C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml'
$keys = { param($p) ([IO.File]::ReadAllLines($p) | Where-Object { $_ -match '^\s*\[?[A-Za-z_]' } | ForEach-Object { ($_ -split '=')[0].Trim() }) -join ', ' }
& $keys $toml
'--- RustDesk2.toml (opcoes):'; & $keys 'C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml'
'--- AnyDesk: arquivos de configuracao:'; Get-ChildItem C:\ProgramData\AnyDesk -File | ForEach-Object { "  $($_.Name) $($_.Length)" }
"MachineGuid atual termina em ...$((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Cryptography').MachineGuid.Substring(30))"
'--- VDE-CE: estado em disco:'; Get-ChildItem 'C:\ProgramData\VDE-CE', 'C:\Program Files\VDE-CE' -ErrorAction SilentlyContinue | ForEach-Object { "  $($_.FullName)" }
(Get-Service | Where-Object { $_.Name -match 'vde|netmonitor' } | Select-Object Name, Status, StartType | Out-String).Trim()
(Get-ScheduledTask | Where-Object { $_.TaskName -match 'vde|netmonitor' } | Select-Object TaskName, State | Out-String).Trim()
reg query 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' 2>$null | Select-String -Pattern 'vde|netmonitor'

'--- pacotes da Store instalados so para usuarios (bloqueiam o sysprep):'
$prov = @((Get-AppxProvisionedPackage -Online).DisplayName)
$bad = Get-AppxPackage -AllUsers | Where-Object { -not $_.IsFramework -and $_.SignatureKind -ne 'System' -and -not $_.NonRemovable -and ($prov -notcontains $_.Name) }
foreach ($p in $bad) {
    try { Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop; "  removido: $($p.Name) $($p.Version)" } catch { "  NAO removido: $($p.Name) -> $($_.Exception.Message.Split([char]10)[0])" }
}
"total tratado: $(@($bad).Count)"
'--- contas:'; (Get-LocalUser | Where-Object { $_.Name -in 'Administrador', 'Aluno', 'CREDE' } | Select-Object Name, Enabled, PasswordRequired | Out-String).Trim()
"reinicio pendente: $(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')  BitLocker C: $((Get-BitLockerVolume C: -ErrorAction SilentlyContinue).ProtectionStatus)"
