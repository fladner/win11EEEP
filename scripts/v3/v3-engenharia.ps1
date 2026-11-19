# v3 do zero, passo 5: engenharia (DVD EEEPEXTRA = build\extra.viso). Rodar como Administrador.
# Baseado nos jobs 59 e 61 da montagem antiga, com o SinuTrain 4.95 (inventario da v2) no lugar do 4.5 HF1 (2013).
# Multisim: so a ISO oficial da NI, sem ativacao (modo de avaliacao). Nenhum ativador/crack.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\v3-engenharia.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
function WaitMsi { for ($i = 0; $i -lt 90 -and (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\InProgress'); $i++) { Start-Sleep 10 } }
function Run($name, $file, $arguments, [int]$min = 60) {
    WaitMsi
    $p = Start-Process -FilePath $file -ArgumentList $arguments -PassThru
    if ($p.WaitForExit($min * 60000)) { L "$name exit=$($p.ExitCode)" } else { L "$name TIMEOUT ($min min)" }
    WaitMsi
}
$v = Get-CimInstance Win32_Volume -Filter "Label='EEEPEXTRA'" | Select-Object -First 1
if ($v -and -not $v.DriveLetter) {
    $free = [char[]](69..90) | Where-Object { -not (Test-Path "$($_):\") } | Select-Object -First 1
    & mountvol "$($free):" $v.DeviceID; L "DVD EEEPEXTRA montado em $($free):"
}
$dvd = (Get-Volume | Where-Object FileSystemLabel -eq 'EEEPEXTRA' | Select-Object -First 1).DriveLetter
if (-not $dvd) { L 'FALHA: DVD EEEPEXTRA nao encontrado'; return }
$tmp = 'C:\ProgramData\EEEPBuild\extra'; New-Item -ItemType Directory -Force $tmp | Out-Null
$7z = 'C:\Program Files\7-Zip\7z.exe'

L '===== Solid Edge Student 2026 (pt-BR) ====='
& $7z x "${dvd}:\solidedge.zip" "-o$tmp\se" -y -bso0 -bsp0; L "extraido (exit=$LASTEXITCODE)"
$se = "$tmp\se\Solid Edge"
$vc = "$se\ISSetupPrerequisites\MS VC++ 2022 Redist (x64)\VC_redist.x64.exe"
if (Test-Path $vc) { Run 'VC++ 2022 x64 (Solid Edge)' $vc @('/install', '/quiet', '/norestart') 15 }
Run 'Solid Edge 2026' "$se\setup.exe" @('/s', '/l1046', "/v`"/qn ALLUSERS=1 REBOOT=ReallySuppress /l*v \`"$tmp\solidedge.log\`"`"") 120
Remove-Item "$tmp\se" -Recurse -Force -ErrorAction SilentlyContinue

L '===== Proteus 9 Demonstration (pre-requisito VC++ 2013 x86) ====='
$out = cmd /c 'winget install --id Microsoft.VCRedist.2013.x86 --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1'
L ("VC++ 2013 x86 exit=0x{0:X8}" -f $LASTEXITCODE)
Copy-Item "${dvd}:\proteus.exe" "$tmp\proteus.exe" -Force
Run 'Proteus 9' "$tmp\proteus.exe" @('/quiet', '/norestart', '/log', "`"$tmp\proteus.log`"") 60
Remove-Item "$tmp\proteus.exe" -Force -ErrorAction SilentlyContinue

L '===== PSIM Demo (Inno Setup) ====='
& $7z e "${dvd}:\psim.zip" "-o$tmp\psim" -y -bso0 -bsp0
$ps = Get-ChildItem "$tmp\psim" -Filter '*.exe' | Select-Object -First 1
Run 'PSIM' $ps.FullName @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', '/ALLUSERS', "/LOG=`"$tmp\psim.log`"") 30

L '===== SinuTrain for SINUMERIK Operate 4.95 + Automation License Manager ====='
& $7z x "${dvd}:\sinutrain495.zip" "-o$tmp\st" -y -bso0 -bsp0; L "extraido (exit=$LASTEXITCODE)"
$st = Get-ChildItem "$tmp\st" -Recurse -Directory -Filter setup | Select-Object -First 1
if ($st) {
    $s = $st.FullName
    if (Test-Path "$s\redist\VC 2015-2022 Redist\VC_redist.x86.exe") { Run 'VC++ 2015-2022 x86 (SinuTrain)' "$s\redist\VC 2015-2022 Redist\VC_redist.x86.exe" @('/install', '/quiet', '/norestart') 15 }
    Run 'Automation License Manager x64' 'msiexec.exe' @('/i', "`"$s\alm\alm64\ALM64\Setup.msi`"", '/qn', '/norestart', 'ALLUSERS=1', '/l*v', "`"$tmp\alm.log`"") 30
    Run 'SinuTrain 4.95' "$s\sinutrain\disk1\setup.exe" @('/s', '/l1033', "/v`"/qn ALLUSERS=1 REBOOT=ReallySuppress /l*v \`"$tmp\sinutrain.log\`"`"") 60
    Run 'SinuTrain CNC-SW 840D sl 4.95 HF1' "$s\s3p\840Dsl\disk1\setup.exe" @('/s', '/l1033', "/v`"/qn ALLUSERS=1 REBOOT=ReallySuppress /l*v \`"$tmp\sinutrain-840dsl.log\`"`"") 60
} else { L 'FALHA: pasta setup do SinuTrain 4.95 nao encontrada' }

L '===== NI Circuit Design Suite 14.2 (Multisim), sem ativacao: modo de avaliacao ====='
Copy-Item "${dvd}:\ni-cds.iso" "$tmp\ni-cds.iso" -Force
$img = Mount-DiskImage -ImagePath "$tmp\ni-cds.iso" -PassThru
$nl = ($img | Get-Volume).DriveLetter
$sig = Get-AuthenticodeSignature "${nl}:\Install.exe"
L "NI Install.exe: $($sig.Status) $($sig.SignerCertificate.Subject -replace ',.*')"
if ($sig.Status -eq 'Valid' -and $sig.SignerCertificate.Subject -like '*National Instruments*') {
    Run 'NI CDS 14.2' "${nl}:\Install.exe" @('--passive', '--accept-eulas', '--prevent-reboot', '--prevent-activation') 120
} else { L 'NI CDS: assinatura invalida, nao instalado' }
Dismount-DiskImage -ImagePath "$tmp\ni-cds.iso" | Out-Null
Remove-Item "$tmp\ni-cds.iso" -Force -ErrorAction SilentlyContinue

L '===== conferencia ====='
L "Solid Edge: $(Test-Path 'C:\Program Files\Siemens\Solid Edge 2026\Program\Edge.exe')"
L "Proteus: $(Test-Path 'C:\Program Files\Labcenter Electronics\Proteus 9 Demonstration\BIN\PDS.EXE')"
$pe = Get-ChildItem 'C:\Powersim', 'C:\Program Files (x86)\Powersim', 'C:\Program Files\Powersim' -Recurse -Filter 'PSIM.exe' -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
L "PSIM: $($pe.FullName)"
$sx = Get-ChildItem 'C:\Program Files (x86)\Siemens', 'C:\Program Files\Siemens' -Recurse -Filter '*.exe' -Depth 4 -ErrorAction SilentlyContinue | Where-Object FullName -match 'SinuTrain' | Select-Object -First 3 -ExpandProperty FullName
L "SinuTrain: $($sx -join '; ')"
L "ALM: $([bool](Get-Service AlmSvc -ErrorAction SilentlyContinue))"
$ms = Get-ChildItem 'C:\Program Files (x86)\National Instruments', 'C:\Program Files\National Instruments' -Recurse -Filter 'multisim.exe' -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
L "Multisim: $($ms.FullName)"
Get-ChildItem 'C:\Users\Public\Desktop\*.lnk' | Where-Object Name -match 'Solid|SinuTrain|Proteus|PSIM|Multisim|Ultiboard' | ForEach-Object { L "atalho: $($_.Name)" }
L "C: livre GB: $([math]::Round((Get-PSDrive C).Free/1GB,1))"
