# Roda COMO o usuario Aluno (tarefa agendada) e verifica acesso aos programas e ferramentas.
$out = 'C:\Users\Public\teste-aluno.txt'
function W($m) { Add-Content $out $m }
Set-Content $out "usuario: $(whoami)  admin: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators'))"
$exes = [ordered]@{
    'VS Code' = 'C:\Program Files\Microsoft VS Code\Code.exe'; 'XAMPP (php)' = 'C:\xampp\php\php.exe'; 'MySQL Workbench' = 'C:\Program Files\MySQL\MySQL Workbench*\MySQLWorkbench.exe'
    'LibreOffice' = 'C:\Program Files\LibreOffice\program\soffice.exe'; 'VirtualBox' = 'C:\Program Files\Oracle\VirtualBox\VirtualBox.exe'; 'Python' = 'C:\Program Files\Python314\python.exe'
    'NetBeans' = 'C:\Program Files\NetBeans-25\netbeans\bin\netbeans64.exe'; 'Arduino IDE' = 'C:\Program Files\arduino-ide\Arduino IDE.exe'; 'Portugol Studio' = 'C:\ProgramData\UNIVALI\Portugol Studio\java\java-windows\bin\javaw.exe'
    'Flutter' = 'C:\Dev\flutter\bin\flutter.bat'; 'Dart' = 'C:\Dev\flutter\bin\dart.bat'; 'AutoCAD' = 'C:\Program Files\Autodesk\AutoCAD 2027\acad.exe'; 'Revit' = 'C:\Program Files\Autodesk\Revit 2027\Revit.exe'
    'Dev-C++' = 'C:\Dev-Cpp\devcpp.exe'; 'Multisim' = 'C:\Program Files (x86)\National Instruments\Circuit Design Suite 14.*\multisim.exe'; 'PSIM' = 'C:\Powersim\PSIM11.1.*_Demo\PSIM.exe'
    'Node.js' = 'C:\Program Files\nodejs\node.exe'; 'IntelliJ IDEA' = 'C:\Program Files\JetBrains\IntelliJ IDEA*\bin\idea64.exe'; 'Git' = 'C:\Program Files\Git\cmd\git.exe'
    'Chrome' = 'C:\Program Files\Google\Chrome\Application\chrome.exe'; 'Anaconda' = 'C:\ProgramData\anaconda3\python.exe'; 'RustDesk' = 'C:\Program Files\RustDesk\rustdesk.exe'; 'AnyDesk' = 'C:\Program Files (x86)\AnyDesk\AnyDesk.exe'
    'Proteus' = 'C:\Program Files\Labcenter Electronics\Proteus 9 Demonstration\BIN\PDS.EXE'; 'Solid Edge' = 'C:\Program Files\Siemens\Solid Edge 2026\Program\Edge.exe'
    'Fusion 360' = 'C:\Program Files\Autodesk\webdeploy\production\*\Fusion360.exe'; 'SinuTrain' = 'C:\Program Files (x86)\Siemens\SinuTrain*\*\sinutrain.exe'
    'Eclipse' = 'C:\Program Files\LabApps\Eclipse\eclipse\eclipse.exe'; 'Android Studio' = 'C:\Program Files\Android\Android Studio\bin\studio64.exe'; 'adb' = 'C:\Android\platform-tools\adb.exe'
    'Packet Tracer' = 'C:\Program Files\Cisco Packet Tracer 9.0.1\bin\PacketTracer.exe'; 'Postman' = "$env:LOCALAPPDATA\Postman\Postman.exe"; 'pgAdmin' = 'C:\Program Files\PostgreSQL\18\pgAdmin 4\runtime\pgAdmin4.exe'
    'VisuAlg' = 'C:\Program Files (x86)\visualg3.0.7\*.exe'; 'GIMP' = 'C:\Program Files\GIMP 3\bin\gimp-3*.exe'; 'Inkscape' = 'C:\Program Files\Inkscape\bin\inkscape.exe'; 'FreeCAD' = 'C:\Program Files\FreeCAD 1.1\bin\FreeCAD.exe'
    'Wireshark' = 'C:\Program Files\Wireshark\Wireshark.exe'; 'CodeBlocks' = 'C:\Program Files\CodeBlocks\codeblocks.exe'; 'Nmap' = 'C:\Program Files (x86)\Nmap\nmap.exe'; 'VDE-CE' = 'C:\Program Files\VDE-CE\netmonitor-agent.exe'
}
W '--- acesso de leitura/execucao aos programas:'
foreach ($k in $exes.Keys) {
    $f = Get-Item $exes[$k] -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $f) { W ("  AUSENTE   {0}  ({1})" -f $k, $exes[$k]); continue }
    try { $s = [IO.File]::OpenRead($f.FullName); $s.Close(); W ("  ok        {0}" -f $k) } catch { W ("  SEM ACESSO {0}: {1}" -f $k, $f.FullName) }
}
W '--- comandos no PATH:'
foreach ($c in 'java -version', 'mvn -v', 'git --version', 'python --version', 'php -v', 'psql --version', 'mysql --version', 'code --version', 'adb version', 'node --version', 'npm --version', 'dart --version', 'flutter --version') {
    $o = cmd /c "$c 2>&1" | Where-Object { $_ } | Select-Object -First 1
    W ("  {0,-18} -> {1}" -f $c, $o)
}
W "JAVA_HOME=$env:JAVA_HOME  ANDROID_HOME=$env:ANDROID_HOME"
W '--- escrita onde o aluno precisa:'
foreach ($d in 'C:\xampp\htdocs', 'C:\Dev\flutter', 'C:\Android', "$env:USERPROFILE\Documents") {
    $t = Join-Path $d 'teste-aluno.tmp'; try { Set-Content $t 'x' -ErrorAction Stop; Remove-Item $t; W "  ok   $d" } catch { W "  NEGADO $d" }
}
W '--- servicos:'
try { W "  http://localhost -> $((Invoke-WebRequest -UseBasicParsing http://localhost/ -TimeoutSec 15).StatusCode)" } catch { W "  http://localhost FALHOU: $($_.Exception.Message)" }
foreach ($p in 3306, 5432) { $c = New-Object Net.Sockets.TcpClient; try { $c.Connect('127.0.0.1', $p); W "  porta $p ok" } catch { W "  porta $p FECHADA" } finally { $c.Close() } }
W "--- extensoes do VS Code: $((cmd /c 'code --list-extensions 2>&1') -join ', ')"
W "--- atalhos na area de trabalho: $(@(Get-ChildItem "$env:USERPROFILE\Desktop", 'C:\Users\Public\Desktop' -Filter *.lnk).Count)"
W 'FIM'
