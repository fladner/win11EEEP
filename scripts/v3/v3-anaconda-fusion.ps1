# v3 do zero, passo 3 (fim): Anaconda para todos os usuarios e Autodesk Fusion para todos os usuarios.
# Mesmos parametros dos jobs 52 e 51 da montagem antiga, sem as remocoes de versoes antigas (sistema limpo).
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\v3-anaconda-fusion.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
function Tail($out) { ($out | Where-Object { $_ -and $_.Trim().Length -gt 3 -and $_ -notmatch '[\u2588\u2592]|^\s*[-\\|/]\s*$' } | Select-Object -Last 1) }

L '== Anaconda (todos os usuarios, sem registrar como Python padrao)'
$o = cmd /c 'winget install --id Anaconda.Anaconda3 --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity --override "/InstallationType=AllUsers /RegisterPython=0 /AddToPath=0 /S /D=C:\ProgramData\anaconda3" 2>&1'
L ("   exit=0x{0:X8} {1}" -f $LASTEXITCODE, (Tail $o))
$av = & 'C:\ProgramData\anaconda3\python.exe' --version 2>&1
L "   Anaconda python: $av ; atalhos: $(@(Get-ChildItem 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Anaconda*' -Recurse -Filter *.lnk -ErrorAction SilentlyContinue).Count)"

L '== Autodesk Fusion (todos os usuarios)'
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
$f = 'C:\ProgramData\EEEPBuild\FusionAdminInstall.exe'
try {
    (New-Object Net.WebClient).DownloadFile('https://dl.appstreaming.autodesk.com/production/installers/Fusion%20Admin%20Install.exe', $f)
    $sig = Get-AuthenticodeSignature $f
    L "   instalador: $([math]::Round((Get-Item $f).Length/1MB,1)) MB assinatura=$($sig.Status) $($sig.SignerCertificate.Subject -replace ',.*$','')"
    if ($sig.Status -eq 'Valid' -and $sig.SignerCertificate.Subject -match 'Autodesk') {
        $p = Start-Process $f -ArgumentList '--globalinstall', '--quiet' -PassThru
        if ($p.WaitForExit(90 * 60000)) { L "   Fusion exit=$($p.ExitCode)" } else { L '   Fusion TIMEOUT (90 min)' }
    } else { L '   assinatura invalida; Fusion NAO instalado' }
} catch { L "   FALHA no download/instalacao do Fusion: $($_.Exception.Message)" }
Remove-Item $f -Force -ErrorAction SilentlyContinue
$fx = Get-ChildItem 'C:\Program Files\Autodesk\webdeploy\production' -Recurse -Filter 'Fusion360.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
L "   Fusion360.exe: $($fx.FullName)"
L ("   atalhos: " + ((Get-ChildItem 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs', 'C:\Users\Public\Desktop' -Recurse -Filter '*Fusion*' -ErrorAction SilentlyContinue | ForEach-Object Name) -join ', '))
L "C: livre GB: $([math]::Round((Get-PSDrive C).Free/1GB,1))"
