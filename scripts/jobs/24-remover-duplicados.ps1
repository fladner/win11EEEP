# Remove versoes antigas duplicadas (Arduino IDE, LibreCAD, NetBeans) e corrige atalhos.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\kit.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
function Msi($arguments) { for ($t = 0; $t -lt 90; $t++) { $p = Start-Process msiexec.exe -ArgumentList $arguments -PassThru -Wait; if ($p.ExitCode -ne 1618) { break }; Start-Sleep 60 }; $p.ExitCode }
function Shortcut($lnk, $target) { $s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk); $s.TargetPath = $target; $s.WorkingDirectory = Split-Path $target; $s.Save() }
$sm = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs'; $pub = 'C:\Users\Public\Desktop'

# --- Arduino IDE: remove 2.0.3 e a 2.3.11 que foi parar no perfil do sistema; reinstala 2.3.11 para todos
Get-Process 'Arduino IDE' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$c = Msi @('/x', '{06BA4131-5D9D-4F96-966F-B43C942E3D76}', '/qn', '/norestart'); L "Arduino 2.0.3 removido exit=$c"
$c = Msi @('/x', '{D1F2C8BA-8149-43F6-8500-4CDAD83C2E51}', '/qn', '/norestart'); L "Arduino 2.3.11 (perfil do sistema) removido exit=$c"
Remove-Item 'C:\Program Files\arduino-ide', 'C:\Windows\system32\config\systemprofile\AppData\Local\Programs\arduino-ide' -Recurse -Force -ErrorAction SilentlyContinue
$msi = (Get-ChildItem 'D:\kit\Pacotes\WinGet\ArduinoSA.IDE.stable' -Filter *.msi | Select-Object -First 1).FullName
$q = '"' + $msi + '"'
$c = Msi @('/i', $q, '/qn', '/norestart', 'ALLUSERS=1'); L "Arduino 2.3.11 (todos os usuarios) exit=$c"

# --- pendencias do kit: JDK 21 (colidiu com outra instalacao) e Android Studio
$jmsi = '"' + (Get-ChildItem 'D:\kit\Pacotes\WinGet\EclipseAdoptium.Temurin.21.JDK' -Filter *.msi | Select-Object -First 1).FullName + '"'
$c = Msi @('/i', $jmsi, '/qn', '/norestart', 'ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome'); L "Temurin JDK 21 exit=$c"
$jdk21 = (Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory -Filter 'jdk-21*' -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
if ($jdk21) {
    [Environment]::SetEnvironmentVariable('JAVA_HOME', $jdk21, 'Machine')
    $mp = @("$jdk21\bin") + (([Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';') | Where-Object { $_ -and $_ -ne "$jdk21\bin" })
    [Environment]::SetEnvironmentVariable('Path', ($mp -join ';'), 'Machine'); L "JAVA_HOME=$jdk21"
} else { L 'FALHA: JDK 21 nao localizado' }
if (-not (Test-Path 'C:\Program Files\Android\Android Studio\bin\studio64.exe')) {
    $as = (Get-ChildItem 'D:\kit\Pacotes\WinGet\Google.AndroidStudio' -Filter *.exe | Select-Object -First 1).FullName
    Copy-Item $as 'C:\ProgramData\EEEPBuild\as.exe' -Force
    $p = Start-Process 'C:\ProgramData\EEEPBuild\as.exe' -ArgumentList '/S' -PassThru; [void]$p.WaitForExit(45 * 60000)
    L "Android Studio exit=$($p.ExitCode) instalado=$(Test-Path 'C:\Program Files\Android\Android Studio\bin\studio64.exe')"
    Remove-Item 'C:\ProgramData\EEEPBuild\as.exe' -Force -ErrorAction SilentlyContinue
}
$ard = Get-ChildItem 'C:\Program Files\Arduino IDE', 'C:\Program Files\arduino-ide' -Filter 'Arduino IDE.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($ard) {
    L "Arduino em $($ard.FullName) versao $($ard.VersionInfo.ProductVersion)"
    Remove-Item 'C:\Users\*\Desktop\Arduino IDE.lnk' -Force -ErrorAction SilentlyContinue
    Shortcut "$pub\Arduino IDE.lnk" $ard.FullName; Shortcut "$sm\Arduino IDE.lnk" $ard.FullName
} else { L 'FALHA: Arduino IDE nao localizado apos reinstalacao' }

# --- LibreCAD 2.2.0 (x86)
if (Test-Path 'C:\Program Files (x86)\LibreCAD\Uninstall.exe') {
    $p = Start-Process 'C:\Program Files (x86)\LibreCAD\Uninstall.exe' -ArgumentList '/S' -PassThru; [void]$p.WaitForExit(600000); Start-Sleep 15
    Remove-Item 'C:\Program Files (x86)\LibreCAD' -Recurse -Force -ErrorAction SilentlyContinue
    L "LibreCAD 2.2.0 removido: $(-not (Test-Path 'C:\Program Files (x86)\LibreCAD\LibreCAD.exe'))"
}
Remove-Item 'C:\Users\*\Desktop\LibreCAD.lnk', "$sm\LibreCAD.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\LibreCAD' -Recurse -Force -ErrorAction SilentlyContinue

# --- NetBeans 16
$jdk = (Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory -Filter 'jdk-21*' | Select-Object -First 1).FullName
if (Test-Path 'C:\Program Files\NetBeans-16\uninstall.exe') {
    $p = Start-Process 'C:\Program Files\NetBeans-16\uninstall.exe' -ArgumentList '--silent', '--javahome', "`"$jdk`"" -PassThru; [void]$p.WaitForExit(20 * 60000); Start-Sleep 10
    L "NetBeans 16 desinstalador exit=$($p.ExitCode)"
}
if (Test-Path 'C:\Program Files\NetBeans-16') {
    Remove-Item 'C:\Program Files\NetBeans-16' -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\nbi-nb-all-16.0.0.221119.0' -Recurse -Force -ErrorAction SilentlyContinue
}
Remove-Item "$sm\Apache NetBeans\Apache NetBeans IDE 16.lnk", 'C:\Users\*\Desktop\Apache NetBeans IDE 16.lnk' -Force -ErrorAction SilentlyContinue
L "NetBeans 16 removido: $(-not (Test-Path 'C:\Program Files\NetBeans-16'))"

# --- atalhos antigos do Packet Tracer nos perfis
$pt = 'C:\Program Files\Cisco Packet Tracer 9.0.1\bin\PacketTracer.exe'
foreach ($l in Get-ChildItem 'C:\Users\*\Desktop\Cisco Packet Tracer.lnk' -ErrorAction SilentlyContinue) { Shortcut $l.FullName $pt }
L 'atalhos do Packet Tracer apontando para a 9.0.1'

# --- conferencia: atalhos quebrados nas areas de trabalho e no menu iniciar
$w = New-Object -ComObject WScript.Shell
$broken = Get-ChildItem 'C:\Users\*\Desktop\*.lnk', "$sm\*.lnk", "$sm\*\*.lnk" -ErrorAction SilentlyContinue | Where-Object { $t = $w.CreateShortcut($_.FullName).TargetPath; $t -and $t -match '^[A-Z]:\\' -and -not (Test-Path -LiteralPath $t) }
"atalhos quebrados: $(@($broken).Count)"; $broken | Select-Object -First 25 | ForEach-Object { "   $($_.FullName)" }
