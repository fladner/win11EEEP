# Base 22/02/2025: o App Installer/WinGet da imagem nao inicia. Repara pelo procedimento oficial
# (modulo Microsoft.WinGet.Client + Repair-WinGetPackageManager -AllUsers), como o kit faz. Rodar como Administrador.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\programas.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
L '===== reparo do WinGet ====='
try {
    if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue | Where-Object Version -ge '2.8.5.201')) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null; L 'provedor NuGet instalado'
    }
    Install-Module Microsoft.WinGet.Client -Force -Scope AllUsers -AllowClobber -Repository PSGallery -ErrorAction Stop
    Import-Module Microsoft.WinGet.Client -Force
    L "modulo Microsoft.WinGet.Client $((Get-Module Microsoft.WinGet.Client).Version)"
    Repair-WinGetPackageManager -AllUsers -Latest -Force -ErrorAction Stop
    L 'Repair-WinGetPackageManager concluido'
} catch { L "FALHA no reparo: $($_.Exception.Message)" }
Start-Sleep 10
$wg = (Get-ChildItem "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | Sort-Object { [version]($_.Directory.Name -split '_')[1] } | Select-Object -Last 1).FullName
L "winget.exe: $wg"
$v = cmd /c "`"$wg`" --version 2>&1"; L "winget --version: $v"
$s = cmd /c "`"$wg`" source update --name winget --disable-interactivity 2>&1"; L ("source update exit=$LASTEXITCODE " + (($s | Select-Object -Last 1) -join ''))
