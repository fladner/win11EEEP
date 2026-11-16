# Troca o AutoCAD 2027 de pre-lancamento (26.0.57, expirado) pelo AutoCAD 2027 oficial (26.0.60), pacote verificado.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\kit.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
function Entries($pattern) {
    foreach ($root in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') {
        foreach ($k in Get-ChildItem $root -ErrorAction SilentlyContinue) { $n = $k.GetValue('DisplayName'); if ($n -like $pattern) { [pscustomobject]@{ Name = $n; Un = $k.GetValue('UninstallString'); Ver = $k.GetValue('DisplayVersion') } } }
    }
}
L '===== AutoCAD 2027 oficial ====='
Get-Process acad, AcEventSync, AcQMod -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$done = $false
foreach ($e in @(Entries '*AutoCAD 2027*')) {
    if ($done -or $e.Un -notmatch '^"?(.+?Installer\.exe)"?\s+(.*)$') { continue }
    L "removendo: $($e.Name) $($e.Ver)"
    $p = Start-Process $Matches[1] -ArgumentList "$($Matches[2]) -q" -PassThru
    if ($p.WaitForExit(60 * 60000)) { L "   remocao exit=$($p.ExitCode)" } else { L '   remocao TIMEOUT' }
    $done = $true
}
for ($i = 0; $i -lt 60 -and (Get-Process Installer, install_manager -ErrorAction SilentlyContinue); $i++) { Start-Sleep 10 }
L ("restante: " + ((Entries '*AutoCAD 2027*' | ForEach-Object { "$($_.Name) $($_.Ver)" }) -join '; '))
$p = Start-Process 'D:\acad2027\Setup.exe' -ArgumentList '-q' -PassThru
if ($p.WaitForExit(120 * 60000)) { L "AutoCAD 2027 Setup exit=$($p.ExitCode)" } else { L 'AutoCAD 2027 TIMEOUT' }
for ($i = 0; $i -lt 60 -and (Get-Process Installer, install_manager -ErrorAction SilentlyContinue); $i++) { Start-Sleep 10 }
$f = Get-Item 'C:\Program Files\Autodesk\AutoCAD 2027\acad.exe' -ErrorAction SilentlyContinue
L "acad.exe: $($f.VersionInfo.FileVersion)"
(Entries '*AutoCAD 2027*') | ForEach-Object { L "instalado: $($_.Name) $($_.Ver)" }
"C: livre GB: $([math]::Round((Get-PSDrive C).Free/1GB,1))"
