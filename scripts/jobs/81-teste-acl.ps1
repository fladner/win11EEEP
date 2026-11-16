# Verificacao equivalente ao teste como Aluno (que exige logon do Aluno): confere se usuarios comuns
# (Usuarios / Usuarios autenticados / Todos) tem leitura+execucao em cada programa e escrita onde precisam,
# e se as ferramentas estao no PATH da MAQUINA (o que o Aluno herda).
$ErrorActionPreference = 'SilentlyContinue'
$sids = 'S-1-5-32-545', 'S-1-5-11', 'S-1-1-0'
function Rights($path) {
    $r = [Security.AccessControl.FileSystemRights]0
    foreach ($a in (Get-Acl -LiteralPath $path).Access) {
        try { $sid = $a.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value } catch { continue }
        if ($sids -contains $sid -and $a.AccessControlType -eq 'Allow') { $r = $r -bor $a.FileSystemRights }
    }
    $r
}
$exes = [ordered]@{
    'VS Code' = 'C:\Program Files\Microsoft VS Code\Code.exe'; 'PHP (XAMPP)' = 'C:\xampp\php\php.exe'; 'MySQL Workbench' = 'C:\Program Files\MySQL\MySQL Workbench*\MySQLWorkbench.exe'
    'LibreOffice' = 'C:\Program Files\LibreOffice\program\soffice.exe'; 'VirtualBox' = 'C:\Program Files\Oracle\VirtualBox\VirtualBox.exe'; 'Python 3.14' = 'C:\Program Files\Python314\python.exe'
    'NetBeans 25' = 'C:\Program Files\NetBeans-25\netbeans\bin\netbeans64.exe'; 'Arduino IDE' = 'C:\Program Files\arduino-ide\Arduino IDE.exe'; 'Portugol Studio' = 'C:\ProgramData\UNIVALI\Portugol Studio\*.exe'
    'Flutter' = 'C:\Dev\flutter\bin\flutter.bat'; 'Dart' = 'C:\Dev\flutter\bin\cache\dart-sdk\bin\dart.exe'; 'AutoCAD 2027' = 'C:\Program Files\Autodesk\AutoCAD 2027\acad.exe'; 'Revit 2027' = 'C:\Program Files\Autodesk\Revit 2027\Revit.exe'
    'Dev-C++' = 'C:\Dev-Cpp\devcpp.exe'; 'Multisim' = 'C:\Program Files (x86)\National Instruments\Circuit Design Suite 14.3\multisim.exe'; 'PSIM' = 'C:\Powersim\PSIM11.1.3_Demo\PSIM.exe'
    'Proteus' = 'C:\Program Files\Labcenter Electronics\Proteus 9 Demonstration\BIN\PDS.EXE'; 'Solid Edge' = 'C:\Program Files\Siemens\Solid Edge 2026\Program\Edge.exe'
    'Fusion 360' = 'C:\Program Files\Autodesk\webdeploy\production\*\Fusion360.exe'; 'SinuTrain' = 'C:\Program Files (x86)\Siemens\SinuTrain\*\*.exe'
    'Eclipse' = 'C:\Program Files\LabApps\Eclipse\eclipse\eclipse.exe'; 'Android Studio' = 'C:\Program Files\Android\Android Studio\bin\studio64.exe'; 'adb' = 'C:\Android\platform-tools\adb.exe'
    'Packet Tracer 9' = 'C:\Program Files\Cisco Packet Tracer 9.0.1\bin\PacketTracer.exe'; 'Postman (perfil Aluno)' = 'C:\Users\Aluno\AppData\Local\Postman\Postman.exe'; 'pgAdmin 4' = 'C:\Program Files\PostgreSQL\18\pgAdmin 4\runtime\pgAdmin4.exe'
    'VisuAlg' = 'C:\Program Files (x86)\visualg3.0.7\*.exe'; 'GIMP 3' = 'C:\Program Files\GIMP 3\bin\gimp-3*.exe'; 'Inkscape' = 'C:\Program Files\Inkscape\bin\inkscape.exe'; 'FreeCAD' = 'C:\Program Files\FreeCAD 1.1\bin\FreeCAD.exe'
    'Wireshark' = 'C:\Program Files\Wireshark\Wireshark.exe'; 'CodeBlocks' = 'C:\Program Files\CodeBlocks\codeblocks.exe'; 'Nmap' = 'C:\Program Files (x86)\Nmap\nmap.exe'; 'Anaconda' = 'C:\ProgramData\anaconda3\python.exe'
    'Java 21' = 'C:\Program Files\Eclipse Adoptium\jdk-21*\bin\java.exe'; 'Maven' = 'C:\Dev\apache-maven-*\bin\mvn.cmd'; 'Git' = 'C:\Program Files\Git\cmd\git.exe'; 'psql 18' = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
    'CAMotics' = 'C:\Program Files (x86)\CAMotics\camotics.exe'; 'SimulIDE' = 'C:\Program Files\SimulIDE_1.0.0-RC3_Win64\simulide.exe'; 'LibreCAD' = 'C:\Program Files\LibreCAD\LibreCAD.exe'
    'Acrobat X Pro' = 'C:\Program Files (x86)\Adobe\Acrobat 10.0\Acrobat\Acrobat.exe'; 'Chrome' = 'C:\Program Files\Google\Chrome\Application\chrome.exe'; 'Firefox' = 'C:\Program Files\Mozilla Firefox\firefox.exe'
    'FluidSIM' = 'C:\Program Files (x86)\Didactic\fsp_stud.pt\*.exe'; 'Open FluidSim' = 'C:\Program Files (x86)\OpenFluidSim\*.exe'; 'KeyShot' = 'C:\Program Files\KeyShot Studio\bin\*.exe'
}
'--- programas (usuario comum precisa de leitura+execucao):'
$ok = 0; $bad = 0
foreach ($k in $exes.Keys) {
    $f = Get-Item $exes[$k] | Select-Object -First 1
    if (-not $f) { "  AUSENTE    $k  ($($exes[$k]))"; $bad++; continue }
    $r = Rights $f.FullName
    if (($r -band [Security.AccessControl.FileSystemRights]::ReadAndExecute) -eq [Security.AccessControl.FileSystemRights]::ReadAndExecute) { $ok++ } else { "  SEM ACESSO $k  $($f.FullName)  ($r)"; $bad++ }
}
"  ok: $ok  problemas: $bad"
'--- escrita onde o aluno precisa:'
foreach ($d in 'C:\xampp\htdocs', 'C:\Dev\flutter', 'C:\Android') { $r = Rights $d; '  {0,-18} {1}' -f $d, $(if ($r -band [Security.AccessControl.FileSystemRights]::Modify) { 'ok (modificar)' } else { "NEGADO ($r)" }) }
'--- PATH da maquina (herdado pelo Aluno):'
$mp = [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';'
foreach ($t in @{ java = 'Eclipse Adoptium'; maven = 'apache-maven'; git = 'Git\cmd'; python = 'Python314'; php = 'xampp\php'; mysql = 'xampp\mysql\bin'; psql = 'PostgreSQL\18\bin'; flutter = 'flutter\bin'; adb = 'platform-tools'; code = 'VS Code\bin'; nmap = 'Nmap' }.GetEnumerator()) {
    '  {0,-8} {1}' -f $t.Key, $(if ($mp | Where-Object { $_ -like "*$($t.Value)*" }) { 'ok' } else { 'FALTA no PATH' })
}
foreach ($v in 'JAVA_HOME', 'MAVEN_HOME', 'ANDROID_HOME', 'ANDROID_SDK_ROOT') { "  $v=$([Environment]::GetEnvironmentVariable($v, 'Machine'))" }
"  git safe.directory: $((& 'C:\Program Files\Git\cmd\git.exe' config --system --get-all safe.directory) -join ', ')"
'--- servicos:'
(Get-Service Apache2.4, mysql, postgresql-x64-18, AnyDesk, RustDesk, npcap | Select-Object Name, Status, StartType | Out-String).Trim()
"  Npcap restrito a administradores: $((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\npcap\Parameters').AdminOnly)"
try { "  http://localhost -> $((Invoke-WebRequest -UseBasicParsing http://localhost/ -TimeoutSec 15).StatusCode)" } catch { "  http://localhost FALHOU" }
'--- perfil do Aluno:'
"  extensoes VS Code: $(@(Get-ChildItem 'C:\Users\Aluno\.vscode\extensions' -Directory).Count)  Postman: $(Test-Path 'C:\Users\Aluno\AppData\Local\Postman\Postman.exe')"
"  atalhos (area de trabalho do Aluno + publica): $(@(Get-ChildItem 'C:\Users\Aluno\Desktop', 'C:\Users\Public\Desktop' -Filter *.lnk).Count)"
'--- atalhos quebrados:'
$w = New-Object -ComObject WScript.Shell; $sm = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs'
Get-ChildItem 'C:\Users\*\Desktop\*.lnk', "$sm\*.lnk", "$sm\*\*.lnk" | Where-Object { $t = $w.CreateShortcut($_.FullName).TargetPath; $t -and $t -match '^[A-Z]:\\' -and -not (Test-Path -LiteralPath $t) } | ForEach-Object { "  $($_.FullName)" }
