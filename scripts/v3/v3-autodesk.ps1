# v3 do zero, passo 5 (fim): AutoCAD 2027 e Revit 2027, pacotes oficiais do DVD EEEPKIT (D:\acad2027, D:\revit2027).
# Mesmos parametros dos jobs 43 e 40 (Setup.exe -q), sem as remocoes de versoes antigas (sistema limpo).
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\v3-autodesk.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
function Sig($f) { $s = Get-AuthenticodeSignature $f; "$($s.Status) $($s.SignerCertificate.Subject -replace ',.*$','')" }
foreach ($prod in @(@{ N = 'AutoCAD 2027'; S = 'D:\acad2027\Setup.exe'; E = 'C:\Program Files\Autodesk\AutoCAD 2027\acad.exe'; M = 120 },
                    @{ N = 'Revit 2027'; S = 'D:\revit2027\Setup.exe'; E = 'C:\Program Files\Autodesk\Revit 2027\Revit.exe'; M = 150 })) {
    L "===== $($prod.N) ====="
    if (-not (Test-Path $prod.S)) { L "FALHA: $($prod.S) nao encontrado"; continue }
    L "Setup.exe: $(Sig $prod.S)"
    $p = Start-Process $prod.S -ArgumentList '-q' -PassThru
    if ($p.WaitForExit($prod.M * 60000)) { L "$($prod.N) Setup exit=$($p.ExitCode)" } else { L "$($prod.N) TIMEOUT ($($prod.M) min)" }
    for ($i = 0; $i -lt 90 -and (Get-Process Installer, install_manager -ErrorAction SilentlyContinue); $i++) { Start-Sleep 10 }
    $f = Get-Item $prod.E -ErrorAction SilentlyContinue
    L "$($prod.N): $(if ($f) { $f.VersionInfo.FileVersion } else { 'NAO encontrado' })"
    L "C: livre GB: $([math]::Round((Get-PSDrive C).Free/1GB,1))"
}
Get-ChildItem 'C:\Users\Public\Desktop\*.lnk' | Where-Object Name -match 'AutoCAD|Revit' | ForEach-Object { L "atalho: $($_.Name)" }
