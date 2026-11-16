$ErrorActionPreference = 'Continue'
$found = $false
foreach ($root in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') {
    foreach ($k in Get-ChildItem $root -ErrorAction SilentlyContinue) {
        $n = $k.GetValue('DisplayName')
        if ($n -notlike 'SketchUp*') { continue }
        $found = $true
        $code = $k.PSChildName; $us = $k.GetValue('UninstallString')
        "encontrado: $n | $code | $us"
        if ($code -match '^\{[0-9A-Fa-f-]{36}\}$') {
            for ($t = 0; $t -lt 10; $t++) {
                $p = Start-Process msiexec.exe -ArgumentList '/x', $code, '/qn', '/norestart' -PassThru -Wait
                "msiexec exit=$($p.ExitCode)"
                if ($p.ExitCode -ne 1618) { break }
                Start-Sleep 60
            }
        } else { "sem ProductCode MSI; UninstallString: $us" }
    }
}
if (-not $found) { 'SketchUp nao encontrado no registro' }
Remove-Item 'C:\Users\Public\Desktop\SketchUp 8.lnk', 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\SketchUp 8' -Recurse -Force -ErrorAction SilentlyContinue
"restos:"; Get-ChildItem 'C:\Program Files (x86)\Google\Google SketchUp 8', 'C:\Program Files (x86)\SketchUp', 'C:\Program Files (x86)\Google' -ErrorAction SilentlyContinue | Select-Object FullName
"atalhos restantes:"; Get-ChildItem C:\Users\*\Desktop\*SketchUp*, 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\*SketchUp*' -ErrorAction SilentlyContinue | Select-Object FullName
