# Segunda passada: programas cuja atualizacao exige remover a versao antiga e instalar a nova.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\programas.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
function Entry($pattern) {
    foreach ($root in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') {
        foreach ($k in Get-ChildItem $root -ErrorAction SilentlyContinue) {
            $n = $k.GetValue('DisplayName'); if ($n -like $pattern) { [pscustomobject]@{ Name = $n; Key = $k.PSChildName; Uninstall = $k.GetValue('UninstallString'); Quiet = $k.GetValue('QuietUninstallString'); Version = $k.GetValue('DisplayVersion') } }
        }
    }
}
function Remove-Old($pattern, $silentArgs) {
    foreach ($e in @(Entry $pattern)) {
        L "removendo $($e.Name) $($e.Version)"
        if ($e.Key -match '^\{[0-9A-Fa-f-]{36}\}$' -and $e.Uninstall -match 'msiexec') {
            $p = Start-Process msiexec.exe -ArgumentList '/x', $e.Key, '/qn', '/norestart' -PassThru -Wait
        } elseif ($e.Uninstall -match '^"?(.+?\.exe)"?') {
            $p = Start-Process $Matches[1] -ArgumentList $silentArgs -PassThru; [void]$p.WaitForExit(40 * 60000); Start-Sleep 20
        } else { L "   sem desinstalador reconhecido: $($e.Uninstall)"; continue }
        L "   exit=$($p.ExitCode)"
    }
}
function Winget-Install($id, $extra) {
    L "== instalando $id"
    $out = cmd /c "winget install --id $id --exact --source winget --scope machine --silent --accept-package-agreements --accept-source-agreements --disable-interactivity $extra 2>&1"
    $code = $LASTEXITCODE
    $tail = ($out | Where-Object { $_ -and $_.Trim().Length -gt 3 -and $_ -notmatch '[\u2588\u2592]|^\s*[-\\|/]\s*$' } | Select-Object -Last 1)
    L ("   exit=0x{0:X8} {1}" -f $code, $tail)
}

# Inkscape 1.2.2 -> 1.4.4
Remove-Old 'Inkscape*' @('/S')
Winget-Install 'Inkscape.Inkscape' ''

# GIMP 2.10.32 -> 3.2
Remove-Old 'GIMP 2*' @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART')
Winget-Install 'GIMP.GIMP.3' ''
Remove-Item 'C:\Users\*\Desktop\GIMP 2.10.32.lnk', 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\GIMP 2.10.32.lnk' -Force -ErrorAction SilentlyContinue

# FreeCAD 0.20.2 -> 1.1
Remove-Old 'FreeCAD 0*' @('/S')
Winget-Install 'FreeCAD.FreeCAD' ''
Remove-Item 'C:\Users\Public\Desktop\FreeCAD 0.20.lnk' -Force -ErrorAction SilentlyContinue

# Python 3.11.2 -> 3.14 (todos os usuarios, no PATH)
$old = Get-ChildItem 'C:\ProgramData\Package Cache' -Recurse -Filter 'python-3.11*-amd64.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($old) { $p = Start-Process $old.FullName -ArgumentList '/uninstall', '/quiet' -PassThru; [void]$p.WaitForExit(20 * 60000); L "Python 3.11 removido exit=$($p.ExitCode)" } else { L 'instalador em cache do Python 3.11 nao encontrado; mantido' }
Winget-Install 'Python.Python.3.14' '--override "/quiet InstallAllUsers=1 PrependPath=1 Include_launcher=1 Include_test=0"'
$mp = ([Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';') | Where-Object { $_ -and ($_ -notlike '*Python311*' -or (Test-Path $_)) }
[Environment]::SetEnvironmentVariable('Path', ($mp -join ';'), 'Machine')
L ("python: " + ((Get-ChildItem 'C:\Program Files\Python3*\python.exe' -ErrorAction SilentlyContinue | ForEach-Object { "$($_.Directory.Name)=$($_.VersionInfo.ProductVersion)" }) -join ' '))

# JDK 17 da Oracle: duplicado mais antigo do Java (o padrao da imagem e o Temurin JDK 21, com JAVA_HOME)
Remove-Old 'Java(TM) SE Development Kit 17*' @('/s')
$mp = ([Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';') | Where-Object { $_ -and $_ -notmatch '\\Java\\jdk-17|Oracle\\Java\\javapath' }
[Environment]::SetEnvironmentVariable('Path', ($mp -join ';'), 'Machine')

L 'fim da segunda passada'
"C: livre GB: $([math]::Round((Get-PSDrive C).Free/1GB,1))"
