# Remove o Python 3.11.2 (componentes MSI) e troca o Anaconda 2024.06 pelo 2026.07 (todos os usuarios).
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\programas.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
L '== Python 3.11.2 (remocao dos componentes)'
$n = 0
foreach ($root in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') {
    foreach ($k in Get-ChildItem $root -ErrorAction SilentlyContinue) {
        $d = $k.GetValue('DisplayName')
        if ($d -like 'Python 3.11.*' -and $k.PSChildName -match '^\{[0-9A-Fa-f-]{36}\}$') {
            $p = Start-Process msiexec.exe -ArgumentList '/x', $k.PSChildName, '/qn', '/norestart' -PassThru -Wait; $n++
            if ($p.ExitCode -ne 0) { L "   $d exit=$($p.ExitCode)" }
        }
    }
}
Remove-Item 'C:\Program Files\Python311' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Python 3.11' -Recurse -Force -ErrorAction SilentlyContinue
L ("   componentes removidos: $n ; restante: " + ((Get-ChildItem 'C:\Program Files\Python3*' -Directory -ErrorAction SilentlyContinue | ForEach-Object Name) -join ' '))
$v = cmd /c 'python --version 2>&1'; L "   python no PATH: $v"

L '== Anaconda 2024.06 -> 2026.07'
if (Test-Path 'C:\ProgramData\anaconda3\Uninstall-Anaconda3.exe') {
    $p = Start-Process 'C:\ProgramData\anaconda3\Uninstall-Anaconda3.exe' -ArgumentList '/S' -PassThru; [void]$p.WaitForExit(60 * 60000)
    for ($i = 0; $i -lt 120 -and (Get-Process 'Un_A', 'Uninstall-Anaconda3' -ErrorAction SilentlyContinue); $i++) { Start-Sleep 5 }
    L "   remocao exit=$($p.ExitCode)"
}
if (Test-Path 'C:\ProgramData\anaconda3') { cmd /c 'rd /s /q C:\ProgramData\anaconda3' }
L "   pasta antiga removida: $(-not (Test-Path 'C:\ProgramData\anaconda3'))"
$o = cmd /c 'winget install --id Anaconda.Anaconda3 --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity --override "/InstallationType=AllUsers /RegisterPython=0 /AddToPath=0 /S /D=C:\ProgramData\anaconda3" 2>&1'
$tail = ($o | Where-Object { $_ -and $_.Trim().Length -gt 3 -and $_ -notmatch '[\u2588\u2592]|^\s*[-\\|/]\s*$' } | Select-Object -Last 1)
L ("   instalacao exit=0x{0:X8} {1}" -f $LASTEXITCODE, $tail)
$av = & 'C:\ProgramData\anaconda3\python.exe' --version 2>&1; L "   Anaconda python: $av ; atalhos: $(@(Get-ChildItem 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Anaconda*' -Recurse -Filter *.lnk -ErrorAction SilentlyContinue).Count)"
"C: livre GB: $([math]::Round((Get-PSDrive C).Free/1GB,1))"
