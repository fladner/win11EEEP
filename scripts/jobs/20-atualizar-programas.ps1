# Atualiza pelo winget os programas ja instalados na imagem (contexto do Administrador).
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\programas.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
$ids = @(
    'Microsoft.VCRedist.2015+.x64', 'Microsoft.VCRedist.2015+.x86', 'Microsoft.VCRedist.2013.x86',
    'Microsoft.DotNet.DesktopRuntime.8', 'Microsoft.DotNet.AspNetCore.8', 'Microsoft.DotNet.DesktopRuntime.10', 'Microsoft.DotNet.AspNetCore.10',
    '7zip.7zip', 'Git.Git', 'Google.Chrome', 'Mozilla.Firefox.pt-BR', 'Microsoft.VisualStudioCode',
    'TheDocumentFoundation.LibreOffice', 'ArduinoSA.IDE.stable', 'Oracle.JDK.17', 'Oracle.MySQLWorkbench',
    'Inkscape.Inkscape', 'LibreCAD.LibreCAD', 'WiresharkFoundation.Wireshark', 'AnyDesk.AnyDesk', 'RustDesk.RustDesk',
    'Oracle.VirtualBox', 'Microsoft.WindowsTerminal', 'Microsoft.AppInstaller'
)
foreach ($id in $ids) {
    L "== $id"
    $out = cmd /c "winget upgrade --id $id --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1"
    $code = $LASTEXITCODE
    $tail = ($out | Where-Object { $_ -and $_.Trim().Length -gt 3 -and $_ -notmatch '[\u2588\u2592]|^\s*[-\\|/]\s*$' } | Select-Object -Last 2) -join ' / '
    L ("   exit=0x{0:X8} {1}" -f $code, $tail)
}
L 'fim das atualizacoes pelo winget'
'reinicio pendente: ' + (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
