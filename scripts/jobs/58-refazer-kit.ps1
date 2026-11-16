# Base 22/02/2025: refaz as partes do kit (jobs\30) que falharam por instalador MSI concorrente ou Git ausente:
# Temurin JDK 21 + JAVA_HOME, NetBeans 25, agente VDE-CE, Packet Tracer 9.0.1 e safe.directory do Flutter.
$ErrorActionPreference = 'Continue'
$P = 'D:\kit\Pacotes'; $W = "$P\WinGet"
$log = 'C:\ProgramData\EEEPBuild\kit.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
function Pick($dir, $filter) { (Get-ChildItem -LiteralPath $dir -Filter $filter -File | Select-Object -First 1).FullName }
# espera outra instalacao MSI terminar (evita o erro 1618)
function WaitMsi { for ($i = 0; $i -lt 90 -and (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\InProgress'); $i++) { Start-Sleep 10 } }
function Run($name, $file, $arguments, [int]$min = 40) {
    WaitMsi
    $p = Start-Process -FilePath $file -ArgumentList $arguments -PassThru
    if ($p.WaitForExit($min * 60000)) { L "$name exit=$($p.ExitCode)"; return $p.ExitCode } else { L "$name TIMEOUT"; return -1 }
}
function AddPath($d, [switch]$First) {
    $cur = [Environment]::GetEnvironmentVariable('Path', 'Machine').Split(';') | Where-Object { $_ }
    if ($cur -contains $d) { return }
    $new = if ($First) { @($d) + $cur } else { $cur + @($d) }
    [Environment]::SetEnvironmentVariable('Path', ($new -join ';'), 'Machine'); L "PATH += $d"
}
L '===== refazer: JDK 21 ====='
if (-not (Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory -Filter 'jdk-21*' -ErrorAction SilentlyContinue)) {
    [void](Run 'Temurin JDK 21' 'msiexec.exe' @('/i', "`"$(Pick "$W\EclipseAdoptium.Temurin.21.JDK" '*.msi')`"", '/qn', '/norestart', 'ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome'))
}
$jdk = (Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory -Filter 'jdk-21*' -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
if ($jdk) { [Environment]::SetEnvironmentVariable('JAVA_HOME', $jdk, 'Machine'); AddPath "$jdk\bin" -First; L "JAVA_HOME=$jdk" } else { L 'FALHA: JDK 21 nao localizado' }

L '===== refazer: NetBeans 25 ====='
if (-not (Test-Path 'C:\Program Files\NetBeans-25\netbeans\bin\netbeans64.exe') -and $jdk) {
    [void](Run 'NetBeans 25' (Pick "$W\Apache.NetBeans" '*.exe') @('--silent', '--javahome', "`"$jdk`""))
}
if (Test-Path 'C:\Program Files\NetBeans-16\uninstall.exe') { [void](Run 'NetBeans 16 (remocao)' 'C:\Program Files\NetBeans-16\uninstall.exe' @('--silent') 20) }
Remove-Item 'C:\Users\Public\Desktop\Apache NetBeans IDE 16.lnk' -Force -ErrorAction SilentlyContinue
L "NetBeans 25: $(Test-Path 'C:\Program Files\NetBeans-25\netbeans\bin\netbeans64.exe')  NetBeans 16: $(Test-Path 'C:\Program Files\NetBeans-16')"

L '===== refazer: Packet Tracer 9.0.1 ====='
if (-not (Test-Path 'C:\Program Files\Cisco Packet Tracer 9.0.1\bin\PacketTracer.exe')) {
    Copy-Item "$P\CiscoPacketTracer_901_win_64bit.exe" 'C:\ProgramData\EEEPBuild\pt901.exe' -Force
    [void](Run 'Packet Tracer 9.0.1' 'C:\ProgramData\EEEPBuild\pt901.exe' @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/SP-', '/NORESTART', '/NOCANCEL', '/ALLUSERS') 45)
    Remove-Item 'C:\ProgramData\EEEPBuild\pt901.exe' -Force -ErrorAction SilentlyContinue
}
L "Packet Tracer 9.0.1: $(Test-Path 'C:\Program Files\Cisco Packet Tracer 9.0.1\bin\PacketTracer.exe')  8.2.0: $(Test-Path 'C:\Program Files\Cisco Packet Tracer 8.2.0')"

L '===== refazer: VDE-CE ====='
if (-not (Test-Path 'C:\Program Files\VDE-CE\netmonitor-agent.exe')) { [void](Run 'VDE-CE Agente' 'msiexec.exe' @('/i', "`"$P\vde-ce-agente-0.8.1.msi`"", '/qn', '/norestart') 15) }
Get-Process netmonitor-agent -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
L "VDE instalado: $(Test-Path 'C:\Program Files\VDE-CE\netmonitor-agent.exe')"

L '===== Git safe.directory do Flutter ====='
if (Test-Path 'C:\Program Files\Git\cmd\git.exe') { & 'C:\Program Files\Git\cmd\git.exe' config --system --add safe.directory 'C:/Dev/flutter'; L 'safe.directory C:/Dev/flutter' } else { L 'Git ainda ausente' }
'reinicio pendente: ' + (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
