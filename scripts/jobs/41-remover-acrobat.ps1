# Remove o "Adobe Acrobat (64-bit)" (Acrobat DC/Reader). O Acrobat X Pro permanece.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\kit.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
$found = @()
foreach ($root in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') {
    foreach ($k in Get-ChildItem $root -ErrorAction SilentlyContinue) {
        $n = $k.GetValue('DisplayName')
        if ($n -like 'Adobe Acrobat*' ) { "entrada: $n | $($k.PSChildName) | $($k.GetValue('DisplayVersion'))" }
        if ($n -eq 'Adobe Acrobat (64-bit)') { $found += $k.PSChildName }
    }
}
Get-Process Acrobat, AcroCEF, AdobeCollabSync, armsvc, AcrobatNotificationClient -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
foreach ($code in $found) {
    if ($code -notmatch '^\{[0-9A-Fa-f-]{36}\}$') { L "Acrobat DC: chave sem ProductCode ($code)"; continue }
    for ($t = 0; $t -lt 60; $t++) {
        $p = Start-Process msiexec.exe -ArgumentList '/x', $code, '/qn', '/norestart' -PassThru -Wait
        if ($p.ExitCode -ne 1618) { break }; Start-Sleep 60
    }
    L "Adobe Acrobat (64-bit) removido: msiexec exit=$($p.ExitCode)"
}
if (-not $found) { L 'Adobe Acrobat (64-bit) nao encontrado' }
Remove-Item 'C:\Users\Public\Desktop\Adobe Acrobat.lnk', 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Adobe Acrobat.lnk' -Force -ErrorAction SilentlyContinue
"Acrobat DC pasta: $(Test-Path 'C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe')"
"Acrobat X Pro presente: $(Test-Path 'C:\Program Files (x86)\Adobe\Acrobat 10.0\Acrobat\Acrobat.exe')"
(Get-Service AdobeARMservice -ErrorAction SilentlyContinue | Select-Object Name, Status | Out-String).Trim()
