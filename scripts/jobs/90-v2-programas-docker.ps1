# Versao 2: atualiza programas (winget, escopo maquina, como SYSTEM) e instala WSL2 + Docker Desktop.
# Ficam de fora: Orwell.Dev-C++ (produto diferente do Dev-C++ 4.9.9.2 escolhido) e NI.ni-packagemanager (Multisim em avaliacao).
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\v2.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
$w = (Get-ChildItem 'C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe' | Sort-Object FullName | Select-Object -Last 1).FullName
function W([string]$verb, [string]$id, [string]$extra = '') {
    L "== $verb $id"
    $out = cmd /c "`"$w`" $verb --id $id --exact --source winget --scope machine --silent --accept-package-agreements --accept-source-agreements --disable-interactivity $extra 2>&1"
    $code = $LASTEXITCODE
    if ($code -and ($out -match 'scope|escopo|No applicable installer|Nenhum instalador')) {
        $out = cmd /c "`"$w`" $verb --id $id --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity $extra 2>&1"
        $code = $LASTEXITCODE
    }
    $tail = ($out | Where-Object { $_ -and $_.Trim().Length -gt 3 -and $_ -notmatch '[\u2588\u2592]|^\s*[-\\|/]\s*$' } | Select-Object -Last 2) -join ' / '
    L ("   exit=0x{0:X8} {1}" -f $code, $tail)
}
foreach ($id in 'Autodesk.AutodeskAccess', 'JetBrains.IntelliJIDEA', 'TheDocumentFoundation.LibreOffice.HelpPack',
                 'Mozilla.Firefox', 'Oracle.MySQLWorkbench', 'Python.Launcher') { W upgrade $id }
W install Google.EarthPro   # pedido do usuario em 17/11 (gratuito); atalhos publicos criados pelo instalador

# WSL2 (base do Docker Desktop)
L '== recursos WSL / VirtualMachinePlatform'
foreach ($f in 'Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform') {
    $r = Enable-WindowsOptionalFeature -Online -FeatureName $f -All -NoRestart
    L "   $f reinicio=$($r.RestartNeeded)"
}
W install Microsoft.WSL
# Docker Desktop para todos os usuarios, backend WSL2, servico sempre ativo (alunos sem admin conseguem usar)
W install Docker.DockerDesktop '--override "install --quiet --accept-license --backend=wsl-2 --always-run-service"'
if (-not (Get-LocalGroup docker-users -ErrorAction SilentlyContinue)) { New-LocalGroup docker-users -Description 'Docker Desktop' | Out-Null }
foreach ($u in 'Aluno', 'Administrador') { Add-LocalGroupMember docker-users -Member $u -ErrorAction SilentlyContinue }
L ("docker-users: " + ((Get-LocalGroupMember docker-users | ForEach-Object Name) -join ', '))
L ("Docker Desktop: " + (Test-Path 'C:\Program Files\Docker\Docker\Docker Desktop.exe'))
L 'fim do job 90'
'reinicio pendente: ' + ((Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
    (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'))
