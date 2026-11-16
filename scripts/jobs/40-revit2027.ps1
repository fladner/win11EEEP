# Remove o Revit 2026 e instala o Revit 2027 (pacote oficial ja verificado) em modo silencioso.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\kit.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
function Entries($pattern) {
    foreach ($root in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') {
        foreach ($k in Get-ChildItem $root -ErrorAction SilentlyContinue) {
            $n = $k.GetValue('DisplayName'); if ($n -like $pattern) { [pscustomobject]@{ Name = $n; Key = $k.PSChildName; Uninstall = $k.GetValue('UninstallString'); Version = $k.GetValue('DisplayVersion') } }
        }
    }
}
L '===== Revit 2027 ====='
"C: livre GB (antes): $([math]::Round((Get-PSDrive C).Free/1GB,1))"
Get-Process Revit, RevitWorker, AdskAccessCore -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
foreach ($e in @(Entries 'Autodesk Revit 2026')) {
    L "removendo: $($e.Name) $($e.Version) | $($e.Uninstall)"
    if ($e.Uninstall -match '^"?(.+?Installer\.exe)"?\s+(.*)$') {
        $exe = $Matches[1]; $rest = $Matches[2]
        $p = Start-Process $exe -ArgumentList "$rest -q" -PassThru
        if ($p.WaitForExit(60 * 60000)) { L "remocao do Revit 2026 exit=$($p.ExitCode)" } else { L 'remocao do Revit 2026 TIMEOUT' }
    } else { L 'formato de desinstalacao inesperado; Revit 2026 mantido' }
}
L ("Revit 2026 ainda presente: " + [bool](Entries 'Autodesk Revit 2026'))
"C: livre GB (apos remocao): $([math]::Round((Get-PSDrive C).Free/1GB,1))"
$setup = 'D:\revit2027\Setup.exe'
if (-not (Test-Path $setup)) { L 'FALHA: D:\revit2027\Setup.exe nao encontrado'; return }
$p = Start-Process $setup -ArgumentList '-q' -PassThru
if ($p.WaitForExit(150 * 60000)) { L "Revit 2027 Setup exit=$($p.ExitCode)" } else { L 'Revit 2027 TIMEOUT (150 min)' }
Start-Sleep 20
(Entries 'Autodesk Revit 20*') | ForEach-Object { L "instalado: $($_.Name) $($_.Version)" }
L "Revit.exe 2027: $(Test-Path 'C:\Program Files\Autodesk\Revit 2027\Revit.exe')"
Remove-Item 'C:\Users\Public\Desktop\Revit 2026.lnk' -Force -ErrorAction SilentlyContinue
"C: livre GB (final): $([math]::Round((Get-PSDrive C).Free/1GB,1))"
