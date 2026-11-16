# Base 22/02/2025: remove o AutoCAD 2025 (e o update 2025.1); o AutoCAD 2027 oficial entra pelo job 42.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\kit.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
function Entries($pattern) {
    foreach ($view in 'Registry64', 'Registry32') {
        $b = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', $view).OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')
        foreach ($n in $b.GetSubKeyNames()) { $k = $b.OpenSubKey($n); $d = "$($k.GetValue('DisplayName'))"; if ($d -like $pattern) { [pscustomobject]@{ Name = $d; Un = "$($k.GetValue('UninstallString'))"; Ver = "$($k.GetValue('DisplayVersion'))" } } }
    }
}
L '===== remocao do AutoCAD 2025 ====='
Get-Process acad, AcEventSync, AcQMod -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
foreach ($e in @(Entries 'Autodesk AutoCAD 2025*' | Sort-Object Name -Descending)) {
    L "removendo: $($e.Name) $($e.Ver) | $($e.Un)"
    if ($e.Un -match '^"?(.+?Installer\.exe)"?\s+(.*)$') { $p = Start-Process $Matches[1] -ArgumentList "$($Matches[2]) -q" -PassThru }
    elseif ($e.Un -match '\{[0-9A-F-]{36}\}') { $p = Start-Process msiexec.exe -ArgumentList '/x', $Matches[0], '/qn', '/norestart' -PassThru }
    else { L '   formato de desinstalacao inesperado'; continue }
    if ($p.WaitForExit(60 * 60000)) { L "   exit=$($p.ExitCode)" } else { L '   TIMEOUT' }
    for ($i = 0; $i -lt 60 -and (Get-Process Installer, install_manager, msiexec -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID }); $i++) { Start-Sleep 10 }
}
Remove-Item 'C:\Users\Public\Desktop\AutoCAD 2025*.lnk', 'C:\Users\*\Desktop\AutoCAD 2025*.lnk' -Force -ErrorAction SilentlyContinue
L ("restante: " + ((Entries '*AutoCAD 2025*' | ForEach-Object { "$($_.Name) $($_.Ver)" }) -join '; '))
"C: livre GB: $([math]::Round((Get-PSDrive C).Free/1GB,1))"
