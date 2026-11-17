# Refaz Proteus (faltava o pre-requisito VC++ 2013 x86) e SinuTrain (o MSI exige o setup.exe do InstallShield).
# Usa os arquivos que o job 59 deixou em C:\ProgramData\EEEPBuild\extra. Rodar como Administrador.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\programas.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
function WaitMsi { for ($i = 0; $i -lt 90 -and (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\InProgress'); $i++) { Start-Sleep 10 } }
$tmp = 'C:\ProgramData\EEEPBuild\extra'

L '===== VC++ 2013 x86 (pre-requisito do Proteus) ====='
$out = cmd /c 'winget install --id Microsoft.VCRedist.2013.x86 --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1'
L ("VC++ 2013 x86 exit=0x{0:X8} {1}" -f $LASTEXITCODE, (($out | Where-Object { $_ -match '\w{4}' } | Select-Object -Last 1) -join ''))

L '===== Proteus 9 Demonstration ====='
WaitMsi
$p = Start-Process "$tmp\proteus.exe" -ArgumentList '/quiet', '/norestart', '/log', "`"$tmp\proteus2.log`"" -PassThru
if ($p.WaitForExit(60 * 60000)) { L "Proteus exit=$($p.ExitCode)" } else { L 'Proteus TIMEOUT' }
L "Proteus: $(Test-Path 'C:\Program Files\Labcenter Electronics\Proteus 9 Demonstration\BIN\PDS.EXE')"

L '===== SinuTrain 4.5 HF1 (setup.exe) ====='
WaitMsi
$p = Start-Process "$tmp\sinutrain\setup.exe" -ArgumentList '/s', '/l1033', "/v`"/qn ALLUSERS=1 REBOOT=ReallySuppress /l*v \`"$tmp\sinutrain2.log\`"`"" -PassThru
if ($p.WaitForExit(40 * 60000)) { L "SinuTrain exit=$($p.ExitCode)" } else { L 'SinuTrain TIMEOUT' }
for ($i = 0; $i -lt 60 -and (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\InProgress'); $i++) { Start-Sleep 10 }
$st = Get-ChildItem 'C:\Program Files (x86)\Siemens', 'C:\Program Files\Siemens' -Recurse -Filter '*.exe' -Depth 4 -ErrorAction SilentlyContinue | Where-Object FullName -match 'SinuTrain' | Select-Object -First 3 -ExpandProperty FullName
L "SinuTrain: $($st -join '; ')"
Get-ChildItem 'C:\Users\Public\Desktop\*.lnk', 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\*\*.lnk' | Where-Object Name -match 'Proteus|SinuTrain' | ForEach-Object { L "atalho: $($_.FullName)" }
