# Instala diretamente (sem o script do kit) os programas do kit implantacao-lab-windows11,
# em escopo de maquina, a partir dos instaladores em D:\kit\Pacotes. Rodar como Administrador.
$ErrorActionPreference = 'Continue'
$P = 'D:\kit\Pacotes'; $W = "$P\WinGet"
$log = 'C:\ProgramData\EEEPBuild\kit.log'
$7z = 'C:\Program Files\7-Zip\7z.exe'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
function Run($name, $file, $arguments, [int]$timeoutMin = 60) {
    if (-not (Test-Path -LiteralPath $file)) { L "$name FALHA: arquivo nao encontrado: $file"; return -2 }
    $p = Start-Process -FilePath $file -ArgumentList $arguments -PassThru
    if (-not $p.WaitForExit($timeoutMin * 60000)) { L "$name TIMEOUT ($timeoutMin min)"; return -1 }
    L "$name exit=$($p.ExitCode)"; return $p.ExitCode
}
function Pick($dir, $filter) { (Get-ChildItem -LiteralPath $dir -Filter $filter -File | Select-Object -First 1).FullName }
function AddPath($d, [switch]$First) {
    $cur = [Environment]::GetEnvironmentVariable('Path', 'Machine').Split(';') | Where-Object { $_ }
    if ($cur -contains $d) { return }
    $new = if ($First) { @($d) + $cur } else { $cur + @($d) }
    [Environment]::SetEnvironmentVariable('Path', ($new -join ';'), 'Machine'); L "PATH += $d"
}
function GrantUsers($path) { & icacls.exe $path /grant '*S-1-5-32-545:(OI)(CI)M' /T /C /Q | Out-Null; L "permissao de modificacao para Usuarios: $path" }
function Unzip($zip, $dest) { New-Item -ItemType Directory -Force $dest | Out-Null; & $7z x $zip "-o$dest" -y -bso0 -bsp0; L "extraido $(Split-Path $zip -Leaf) -> $dest (exit=$LASTEXITCODE)" }
function Shortcut($lnk, $target, $workdir, $icon) {
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk); $s.TargetPath = $target
    if ($workdir) { $s.WorkingDirectory = $workdir }; if ($icon) { $s.IconLocation = $icon }; $s.Save()
}
$startMenu = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs'; $pubDesk = 'C:\Users\Public\Desktop'

L '===== 1. Temurin JDK 21 ====='
$msi = Pick "$W\EclipseAdoptium.Temurin.21.JDK" '*.msi'
[void](Run 'Temurin JDK 21' 'msiexec.exe' @('/i', "`"$msi`"", '/qn', '/norestart', 'ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome'))
$jdk = (Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory -Filter 'jdk-21*' | Select-Object -First 1).FullName
if ($jdk) { [Environment]::SetEnvironmentVariable('JAVA_HOME', $jdk, 'Machine'); AddPath "$jdk\bin" -First; $env:JAVA_HOME = $jdk; L "JAVA_HOME=$jdk" } else { L 'FALHA: JDK 21 nao localizado' }

L '===== 2. Maven ====='
$zip = Pick "$P\Maven" 'apache-maven-*-bin.zip'
Unzip $zip 'C:\Dev'
$mvn = (Get-ChildItem 'C:\Dev' -Directory -Filter 'apache-maven-*' | Select-Object -First 1).FullName
if ($mvn) { [Environment]::SetEnvironmentVariable('MAVEN_HOME', $mvn, 'Machine'); AddPath "$mvn\bin" }

L '===== 3. Eclipse IDE for Java ====='
Unzip (Pick "$W\EclipseFoundation.Eclipse.Java" '*.zip') 'C:\Program Files\LabApps\Eclipse'
$ecl = 'C:\Program Files\LabApps\Eclipse\eclipse\eclipse.exe'
if (Test-Path $ecl) { Shortcut "$startMenu\Eclipse IDE for Java.lnk" $ecl (Split-Path $ecl); Shortcut "$pubDesk\Eclipse IDE for Java.lnk" $ecl (Split-Path $ecl); L 'Eclipse OK' } else { L 'FALHA: eclipse.exe nao localizado' }

L '===== 4. NetBeans 25 (substitui o 16) ====='
if (Test-Path 'C:\Program Files\NetBeans-16\uninstall.exe') { [void](Run 'NetBeans 16 (remocao)' 'C:\Program Files\NetBeans-16\uninstall.exe' @('--silent') 20) }
[void](Run 'NetBeans 25' (Pick "$W\Apache.NetBeans" '*.exe') @('--silent', '--javahome', "`"$jdk`"") 40)
Remove-Item "$pubDesk\Apache NetBeans IDE 16.lnk" -Force -ErrorAction SilentlyContinue

L '===== 5. Android Studio ====='
[void](Run 'Android Studio' (Pick "$W\Google.AndroidStudio" '*.exe') @('/S') 40)

L '===== 6. Android SDK (API 36) ====='
Unzip "$P\Android\android-sdk-api36.zip" 'C:\Android'
[Environment]::SetEnvironmentVariable('ANDROID_HOME', 'C:\Android', 'Machine')
[Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', 'C:\Android', 'Machine')
AddPath 'C:\Android\platform-tools'; AddPath 'C:\Android\emulator'; AddPath 'C:\Android\cmdline-tools\latest\bin'
GrantUsers 'C:\Android'
L "adb presente: $(Test-Path C:\Android\platform-tools\adb.exe); licencas: $(@(Get-ChildItem C:\Android\licenses -ErrorAction SilentlyContinue).Count)"

L '===== 7. Flutter + Dart ====='
Unzip (Pick "$P\Flutter" 'flutter_windows_*stable.zip') 'C:\Dev'
AddPath 'C:\Dev\flutter\bin'
& 'C:\Program Files\Git\cmd\git.exe' config --system --add safe.directory 'C:/Dev/flutter'
GrantUsers 'C:\Dev\flutter'
$env:Path = "C:\Dev\flutter\bin;C:\Program Files\Git\cmd;$env:Path"
$fv = cmd /c 'C:\Dev\flutter\bin\flutter.bat --version 2>&1'; L ("flutter: " + (($fv | Select-Object -First 3) -join ' | '))
GrantUsers 'C:\Dev\flutter'

L '===== 8. Cisco Packet Tracer 9.0.1 (substitui o 8.2.0) ====='
$old = Get-ChildItem 'C:\Program Files\Cisco Packet Tracer 8.2.0' -Filter 'unins*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($old) { [void](Run 'Packet Tracer 8.2.0 (remocao)' $old.FullName @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') 20) }
Copy-Item "$P\CiscoPacketTracer_901_win_64bit.exe" 'C:\ProgramData\EEEPBuild\pt901.exe' -Force
[void](Run 'Packet Tracer 9.0.1' 'C:\ProgramData\EEEPBuild\pt901.exe' @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/SP-', '/NORESTART', '/NOCANCEL', '/ALLUSERS') 45)
Remove-Item 'C:\ProgramData\EEEPBuild\pt901.exe' -Force -ErrorAction SilentlyContinue

L '===== 9. Agente VDE-CE ====='
[void](Run 'VDE-CE Agente' 'msiexec.exe' @('/i', "`"$P\vde-ce-agente-0.8.1.msi`"", '/qn', '/norestart') 15)
Get-Process netmonitor-agent -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
L "VDE instalado: $(Test-Path 'C:\Program Files\VDE-CE\netmonitor-agent.exe')"

L '===== 10. Atalhos e modelos ====='
Set-Content -LiteralPath "$pubDesk\Figma (Web).url" -Value "[InternetShortcut]`r`nURL=https://www.figma.com/" -Encoding ASCII
New-Item -ItemType Directory -Force 'C:\Users\Public\Documents\Modelos' | Out-Null
Copy-Item 'D:\kit\Modelos\*' 'C:\Users\Public\Documents\Modelos' -Recurse -Force
L 'atalho do Figma e modelos Spring/Selenium em Documentos Publicos\Modelos'

L '===== fim do kit (parte silenciosa) ====='
'reinicio pendente: ' + (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
