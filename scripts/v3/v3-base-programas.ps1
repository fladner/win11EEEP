# v3 do zero: programas que vinham "de graca" na base antiga (23H2) e nao tinham script proprio.
# Rodar como Administrador na VM nova (modo de auditoria), com internet. So instaladores oficiais (WinGet).
# Open FluidSim e SimulIDE nao estao no WinGet: baixar do site oficial e extrair (ver ROTEIRO-V3.md, passo 6).
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\v3-base.log'
New-Item -ItemType Directory -Force (Split-Path $log) | Out-Null
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
$w = (Get-Command winget.exe -ErrorAction SilentlyContinue).Source
if (-not $w) { $w = (Get-ChildItem 'C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe' -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1).FullName }
L "winget: $w"
function W([string]$id, [string]$extra = '') {
    L "== install $id"
    $out = cmd /c "`"$w`" install --id $id --exact --source winget --scope machine --silent --accept-package-agreements --accept-source-agreements --disable-interactivity $extra 2>&1"
    $code = $LASTEXITCODE
    if ($code -and ($out -match 'scope|escopo|No applicable installer|Nenhum instalador')) {
        $out = cmd /c "`"$w`" install --id $id --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity $extra 2>&1"
        $code = $LASTEXITCODE
    }
    $tail = ($out | Where-Object { $_ -and $_.Trim().Length -gt 3 -and $_ -notmatch '[\u2588\u2592]|^\s*[-\\|/]\s*$' } | Select-Object -Last 2) -join ' / '
    L ("   exit=0x{0:X8} {1}" -f $code, $tail)
}
& $w source update --name winget 2>&1 | Out-Null

foreach ($id in 'Microsoft.VCRedist.2015+.x64', 'Microsoft.VCRedist.2015+.x86',
                 'Google.Chrome', 'Mozilla.Firefox.pt-BR', 'WiresharkFoundation.Wireshark', 'LibreCAD.LibreCAD',
                 'AnyDesk.AnyDesk', 'Inkscape.Inkscape', 'GIMP.GIMP.3', 'FreeCAD.FreeCAD',
                 'CodeBlocks.CodeBlocks', 'OpenJS.NodeJS.LTS', 'JetBrains.IntelliJIDEA', 'Google.EarthPro') { W $id }
W 'Python.Python.3.14' '--override "/quiet InstallAllUsers=1 PrependPath=1 Include_launcher=1 Include_test=0"'

# Chrome: o manifesto do WinGet costuma ficar com o hash velho (0x8A150011); MSI empresarial oficial do Google
if (-not (Test-Path 'C:\Program Files\Google\Chrome\Application\chrome.exe')) {
    $ProgressPreference = 'SilentlyContinue'
    $m = 'C:\ProgramData\EEEPBuild\chrome.msi'
    Invoke-WebRequest 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi' -OutFile $m -UseBasicParsing
    $sig = Get-AuthenticodeSignature $m
    L "Chrome MSI: assinatura=$($sig.Status) $($sig.SignerCertificate.Subject)"
    if ($sig.Status -eq 'Valid' -and $sig.SignerCertificate.Subject -match 'O=Google LLC') {
        $p = Start-Process msiexec.exe -ArgumentList '/i', "`"$m`"", '/qn', '/norestart' -PassThru; [void]$p.WaitForExit(900000); L "Chrome MSI exit=$($p.ExitCode)"
    }
    Remove-Item $m -Force -ErrorAction SilentlyContinue
}
# Code::Blocks: o WinGet instala como pacote portatil da maquina (sem atalhos)
$cb = 'C:\Program Files\WinGet\Packages\CodeBlocks.CodeBlocks_Microsoft.Winget.Source_8wekyb3d8bbwe\codeblocks.exe'
if (Test-Path $cb) {
    $sh = New-Object -ComObject WScript.Shell
    foreach ($l in 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Code-Blocks.lnk', 'C:\Users\Public\Desktop\Code-Blocks.lnk') {
        $s = $sh.CreateShortcut($l); $s.TargetPath = $cb; $s.WorkingDirectory = Split-Path $cb; $s.Save()
    }
    L 'Code::Blocks: atalhos publicos criados'
}

L '== conferencia'
$chk = [ordered]@{
    'Chrome'    = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
    'Firefox'   = 'C:\Program Files\Mozilla Firefox\firefox.exe'
    'Wireshark' = 'C:\Program Files\Wireshark\Wireshark.exe'
    'LibreCAD'  = 'C:\Program Files*\LibreCAD\LibreCAD.exe'
    'AnyDesk'   = 'C:\Program Files (x86)\AnyDesk\AnyDesk.exe'
    'Inkscape'  = 'C:\Program Files\Inkscape\bin\inkscape.exe'
    'GIMP'      = 'C:\Program Files\GIMP 3\bin\gimp-3*.exe'
    'FreeCAD'   = 'C:\Program Files\FreeCAD*\bin\FreeCAD.exe'
    'CodeBlocks'= 'C:\Program Files\WinGet\Packages\CodeBlocks.CodeBlocks_*\codeblocks.exe'
    'Node.js'   = 'C:\Program Files\nodejs\node.exe'
    'IntelliJ'  = 'C:\Program Files\JetBrains\IntelliJ IDEA*\bin\idea64.exe'
    'Earth Pro' = 'C:\Program Files\Google\Google Earth Pro\client\googleearth.exe'
    'Python'    = 'C:\Program Files\Python314\python.exe'
}
foreach ($k in $chk.Keys) { L ("{0,-11} {1}" -f $k, [bool](Get-Item $chk[$k] -ErrorAction SilentlyContinue)) }
L 'fim'
