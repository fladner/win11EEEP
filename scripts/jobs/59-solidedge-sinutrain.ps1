# Solid Edge Student 2026 (pt-BR) e SinuTrain for SINUMERIK Operate 4.5 HF1, por maquina.
# Instaladores do usuario no DVD EEEPEXTRA (build\extra.viso). Rodar como Administrador.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\programas.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
function WaitMsi { for ($i = 0; $i -lt 90 -and (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\InProgress'); $i++) { Start-Sleep 10 } }
$dvd = (Get-Volume | Where-Object FileSystemLabel -eq 'EEEPEXTRA' | Select-Object -First 1).DriveLetter
if (-not $dvd) { L 'FALHA: DVD EEEPEXTRA nao encontrado'; return }
$tmp = 'C:\ProgramData\EEEPBuild\extra'; New-Item -ItemType Directory -Force $tmp | Out-Null
$7z = 'C:\Program Files\7-Zip\7z.exe'

L '===== SinuTrain 4.5 HF1 ====='
& $7z x "${dvd}:\sinutrain.zip" "-o$tmp\sinutrain" -y -bso0 -bsp0; L "extraido (exit=$LASTEXITCODE)"
WaitMsi
$p = Start-Process msiexec.exe -ArgumentList '/i', "`"$tmp\sinutrain\sinutrain.msi`"", "TRANSFORMS=`"$tmp\sinutrain\1033.mst`"", 'ALLUSERS=1', '/qn', '/norestart', '/l*v', "`"$tmp\sinutrain.log`"" -PassThru
if ($p.WaitForExit(40 * 60000)) { L "SinuTrain exit=$($p.ExitCode)" } else { L 'SinuTrain TIMEOUT' }

L '===== Solid Edge Student 2026 (pt-BR) ====='
& $7z x "${dvd}:\solidedge.zip" "-o$tmp\se" -y -bso0 -bsp0; L "extraido (exit=$LASTEXITCODE)"
$se = "$tmp\se\Solid Edge"
WaitMsi
$vc = "$se\ISSetupPrerequisites\MS VC++ 2022 Redist (x64)\VC_redist.x64.exe"
if (Test-Path $vc) { $p = Start-Process $vc -ArgumentList '/install', '/quiet', '/norestart' -PassThru; [void]$p.WaitForExit(15 * 60000); L "VC++ 2022 x64 exit=$($p.ExitCode)" }
WaitMsi
$p = Start-Process "$se\setup.exe" -ArgumentList '/s', '/l1046', "/v`"/qn ALLUSERS=1 REBOOT=ReallySuppress /l*v \`"$tmp\solidedge.log\`"`"" -PassThru
if ($p.WaitForExit(120 * 60000)) { L "Solid Edge setup exit=$($p.ExitCode)" } else { L 'Solid Edge TIMEOUT' }
for ($i = 0; $i -lt 90 -and (Get-Process msiexec, setup -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$tmp*" -or $_.Name -eq 'msiexec' }) -and (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\InProgress'); $i++) { Start-Sleep 10 }

L '===== Proteus 9 Demonstration ====='
if (Test-Path "${dvd}:\proteus.exe") {
    WaitMsi
    Copy-Item "${dvd}:\proteus.exe" "$tmp\proteus.exe" -Force
    $p = Start-Process "$tmp\proteus.exe" -ArgumentList '/quiet', '/norestart', '/log', "`"$tmp\proteus.log`"" -PassThru
    if ($p.WaitForExit(60 * 60000)) { L "Proteus exit=$($p.ExitCode)" } else { L 'Proteus TIMEOUT' }
    L "Proteus: $(Test-Path 'C:\Program Files\Labcenter Electronics\Proteus 9 Demonstration\BIN\PDS.EXE')"
}

L '===== PSIM 11.1.7 Demo (Inno Setup) ====='
if (Test-Path "${dvd}:\psim.zip") {
    & $7z e "${dvd}:\psim.zip" "-o$tmp\psim" -y -bso0 -bsp0
    $ps = Get-ChildItem "$tmp\psim" -Filter '*.exe' | Select-Object -First 1
    $p = Start-Process $ps.FullName -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', '/ALLUSERS', "/LOG=`"$tmp\psim.log`"" -PassThru
    if ($p.WaitForExit(30 * 60000)) { L "PSIM exit=$($p.ExitCode)" } else { L 'PSIM TIMEOUT' }
    $pe = Get-ChildItem 'C:\Powersim', 'C:\Program Files (x86)\Powersim', 'C:\Program Files\Powersim' -Recurse -Filter 'PSIM.exe' -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
    L "PSIM: $($pe.FullName)"
}

L '===== NI Circuit Design Suite 14.2 (Multisim), sem ativacao: modo de avaliacao ====='
# Somente a ISO oficial da NI (assinatura National Instruments). Nenhum ativador/crack e usado.
if (Test-Path "${dvd}:\ni-cds.iso") {
    Copy-Item "${dvd}:\ni-cds.iso" "$tmp\ni-cds.iso" -Force
    $img = Mount-DiskImage -ImagePath "$tmp\ni-cds.iso" -PassThru
    $nl = ($img | Get-Volume).DriveLetter
    $sig = Get-AuthenticodeSignature "${nl}:\Install.exe"
    L "NI Install.exe: $($sig.Status) $($sig.SignerCertificate.Subject -replace ',.*')"
    if ($sig.Status -eq 'Valid' -and $sig.SignerCertificate.Subject -like '*National Instruments*') {
        WaitMsi
        $p = Start-Process "${nl}:\Install.exe" -ArgumentList '--passive', '--accept-eulas', '--prevent-reboot', '--prevent-activation' -PassThru
        if ($p.WaitForExit(120 * 60000)) { L "NI CDS exit=$($p.ExitCode)" } else { L 'NI CDS TIMEOUT' }
    } else { L 'NI CDS: assinatura invalida, nao instalado' }
    Dismount-DiskImage -ImagePath "$tmp\ni-cds.iso" | Out-Null
    $ms = Get-ChildItem 'C:\Program Files (x86)\National Instruments', 'C:\Program Files\National Instruments' -Recurse -Filter 'multisim.exe' -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
    L "Multisim: $($ms.FullName)"
}

L '===== conferencia ====='
L "Solid Edge: $(Test-Path 'C:\Program Files\Siemens\Solid Edge 2026\Program\Edge.exe')"
$st = Get-ChildItem 'C:\Program Files (x86)\Siemens\SinuTrain', 'C:\Program Files\Siemens\SinuTrain' -Recurse -Filter '*.exe' -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 3 -ExpandProperty FullName
L "SinuTrain: $($st -join '; ')"
Get-ChildItem 'C:\Users\Public\Desktop\*.lnk' | Where-Object Name -match 'Solid|SinuTrain' | ForEach-Object { L "atalho: $($_.Name)" }
if ((Test-Path 'C:\Program Files\Siemens\Solid Edge 2026\Program\Edge.exe') -and $st) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue; L 'arquivos temporarios removidos' }
"C: livre GB: $([math]::Round((Get-PSDrive C).Free/1GB,1))"
