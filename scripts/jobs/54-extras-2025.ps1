# Base 22/02/2025 (Windows 11 23H2): instala os programas que a imagem 26H2 tinha e esta base nao tem.
# Rodar como Administrador (agente user). Instaladores locais em D:\kit\Pacotes\Extras; o resto pelo WinGet.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\programas.log'
$X = 'D:\kit\Pacotes\Extras'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
function Run($name, $file, $arguments, [int]$min = 30) {
    if (-not (Test-Path -LiteralPath $file)) { L "$name FALHA: arquivo nao encontrado: $file"; return }
    $p = Start-Process -FilePath $file -ArgumentList $arguments -PassThru
    if ($p.WaitForExit($min * 60000)) { L "$name exit=$($p.ExitCode)" } else { L "$name TIMEOUT ($min min)" }
}
$wg = (Get-Command winget.exe -ErrorAction SilentlyContinue).Source
if (-not $wg) { $wg = (Get-ChildItem "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1).FullName }
L "winget: $wg $(if ($wg) { & $wg --version })"
function WG($id, $extra = '') {
    if (-not $wg) { L "$id FALHA: winget ausente"; return }
    $out = cmd /c "`"$wg`" install --id $id --exact --source winget --scope machine --silent --accept-package-agreements --accept-source-agreements --disable-interactivity $extra 2>&1"
    $code = $LASTEXITCODE
    # sem alternativa "por usuario": todos os programas precisam ficar disponiveis para todos os usuarios

    L ("{0} exit=0x{1:X8} {2}" -f $id, $code, (($out | Where-Object { $_ -and $_.Trim().Length -gt 3 -and $_ -notmatch '[\u2588\u2592]|^\s*[-\\|/]\s*$' } | Select-Object -Last 1) -join ''))
}

L '===== WinGet (por maquina) ====='
& $wg source update --name winget 2>&1 | Out-Null
foreach ($id in 'Microsoft.VCRedist.2015+.x64', 'Microsoft.VCRedist.2015+.x86', 'Git.Git', 'RustDesk.RustDesk', 'Python.Python.3.14', 'CodeBlocks.CodeBlocks', 'OpenJS.NodeJS.LTS', 'JetBrains.IntelliJIDEA.Community') { WG $id }

L '===== instaladores locais ====='
Run 'MySQL Workbench 8.0.36' 'msiexec.exe' @('/i', "`"$X\mysql-workbench-community-8.0.36-winx64.msi`"", '/qn', '/norestart', 'ALLUSERS=1')
Run 'Portugol Studio 2.7.5' "$X\portugol-studio-2.7.5-windows.exe" @('--mode', 'unattended', '--unattendedmodeui', 'none')
Run 'Dev-C++ 4.9.9.2' "$X\devcpp-4.9.9.2_setup.exe" @('/S')
foreach ($e in Get-ChildItem $X -Filter 'Proteus*.exe' -ErrorAction SilentlyContinue) { Run 'Proteus' $e.FullName @('/S') 60 }
foreach ($z in Get-ChildItem $X -Filter 'SimulIDE*.zip' -ErrorAction SilentlyContinue) {
    & 'C:\Program Files\7-Zip\7z.exe' x $z.FullName '-oC:\Program Files\SimulIDE' -y -bso0 -bsp0; L "SimulIDE extraido (exit=$LASTEXITCODE)"
}

L '===== conferencia ====='
$chk = [ordered]@{
    'Git' = 'C:\Program Files\Git\cmd\git.exe'; 'RustDesk' = 'C:\Program Files\RustDesk\rustdesk.exe'; 'Python 3.14' = 'C:\Program Files\Python314\python.exe'
    'CodeBlocks' = 'C:\Program Files\CodeBlocks\codeblocks.exe'; 'MySQL Workbench' = 'C:\Program Files\MySQL\MySQL Workbench 8.0*\MySQLWorkbench.exe'
    'Portugol Studio' = 'C:\ProgramData\UNIVALI\Portugol Studio\*.exe'; 'Dev-C++' = 'C:\Dev-Cpp\devcpp.exe'
    'Node.js' = 'C:\Program Files\nodejs\node.exe'; 'IntelliJ IDEA' = 'C:\Program Files\JetBrains\IntelliJ IDEA*\bin\idea64.exe'
}
foreach ($k in $chk.Keys) { L ("{0,-16} {1}" -f $k, [bool](Get-Item $chk[$k] -ErrorAction SilentlyContinue)) }
L "servico RustDesk: $((Get-Service RustDesk -ErrorAction SilentlyContinue).Status)"
'reinicio pendente: ' + (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
