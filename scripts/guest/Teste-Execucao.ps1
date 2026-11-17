# Roda NA SESSAO do Aluno (tarefa agendada interativa): abre cada programa, espera a janela principal
# aparecer, registra o titulo e fecha. Resultado em C:\Users\Public\teste-exec.txt.
param([int]$Espera = 45)
$out = 'C:\Users\Public\teste-exec.txt'
function W($m) { Add-Content $out $m }
Set-Content $out "usuario: $(whoami)  inicio: $(Get-Date -Format HH:mm:ss)"
$progs = [ordered]@{
    'VS Code' = 'C:\Program Files\Microsoft VS Code\Code.exe'; 'LibreOffice Writer' = 'C:\Program Files\LibreOffice\program\swriter.exe'
    'Chrome' = 'C:\Program Files\Google\Chrome\Application\chrome.exe'; 'MySQL Workbench' = 'C:\Program Files\MySQL\MySQL Workbench 8.0*\MySQLWorkbench.exe'
    'pgAdmin' = 'C:\Program Files\PostgreSQL\18\pgAdmin 4\runtime\pgAdmin4.exe'; 'XAMPP Control' = 'C:\xampp\xampp-control.exe'
    'Postman' = "$env:LOCALAPPDATA\Postman\Postman.exe"; 'NetBeans' = 'C:\Program Files\NetBeans-25\netbeans\bin\netbeans64.exe'
    'Eclipse' = 'C:\Program Files\LabApps\Eclipse\eclipse\eclipse.exe'; 'IntelliJ IDEA' = 'C:\Program Files\JetBrains\IntelliJ IDEA*\bin\idea64.exe'
    'Android Studio' = 'C:\Program Files\Android\Android Studio\bin\studio64.exe'; 'Packet Tracer' = 'C:\Program Files\Cisco Packet Tracer 9.0.1\bin\PacketTracer.exe'
    'Wireshark' = 'C:\Program Files\Wireshark\Wireshark.exe'; 'Arduino IDE' = 'C:\Program Files\arduino-ide\Arduino IDE.exe'
    'VisuAlg' = 'C:\Program Files (x86)\visualg3.0.7\visualg30.exe'; 'Portugol Studio' = 'C:\Users\Public\Desktop\Portugol Studio.lnk'
    'Dev-C++' = 'C:\Dev-Cpp\devcpp.exe'; 'CodeBlocks' = 'C:\Program Files\CodeBlocks\codeblocks.exe'
    'VirtualBox' = 'C:\Program Files\Oracle\VirtualBox\VirtualBox.exe'; 'GIMP' = 'C:\Program Files\GIMP 3\bin\gimp-3*.exe'
    'Inkscape' = 'C:\Program Files\Inkscape\bin\inkscape.exe'; 'FreeCAD' = 'C:\Program Files\FreeCAD 1.1\bin\freecad.exe'
    'AutoCAD 2027' = 'C:\Program Files\Autodesk\AutoCAD 2027\acad.exe'; 'Revit 2027' = 'C:\Program Files\Autodesk\Revit 2027\Revit.exe'
    'Fusion' = 'C:\Program Files\Autodesk\webdeploy\production\*\Fusion360.exe'; 'Solid Edge' = 'C:\Program Files\Siemens\Solid Edge 2026\Program\Edge.exe'
    'SinuTrain' = 'C:\Program Files (x86)\Siemens\SinuTrain*\*\sinutrain.exe'; 'Proteus' = 'C:\Program Files\Labcenter Electronics\Proteus 9 Demonstration\BIN\PDS.EXE'
    'Multisim' = 'C:\Program Files (x86)\National Instruments\Circuit Design Suite 14.*\multisim.exe'; 'PSIM' = 'C:\Powersim\PSIM11.1.*_Demo\PSIM.exe'
    'AnyDesk' = 'C:\Program Files (x86)\AnyDesk\AnyDesk.exe'; 'RustDesk' = 'C:\Program Files\RustDesk\rustdesk.exe'
    'Anaconda Navigator' = 'C:\ProgramData\anaconda3\pythonw.exe'
}
foreach ($k in $progs.Keys) {
    $f = Get-Item $progs[$k] -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $f) { W ("AUSENTE   {0}" -f $k); continue }
    $antes = @(Get-Process | Select-Object -ExpandProperty Id)
    $args = if ($k -eq 'Anaconda Navigator') { @('C:\ProgramData\anaconda3\Scripts\anaconda-navigator-script.py') } else { @() }
    try { $p = if ($args) { Start-Process $f.FullName -ArgumentList $args -PassThru } else { Start-Process $f.FullName -PassThru } } catch { W ("ERRO      {0}: {1}" -f $k, $_.Exception.Message); continue }
    $titulo = ''; $t0 = Get-Date
    while (((Get-Date) - $t0).TotalSeconds -lt $Espera -and -not $titulo) {
        Start-Sleep 3
        $titulo = (Get-Process | Where-Object { $_.Id -notin $antes -and $_.MainWindowTitle } | Select-Object -First 1 | ForEach-Object { "$($_.ProcessName): $($_.MainWindowTitle)" })
    }
    $s = [int]((Get-Date) - $t0).TotalSeconds
    if ($titulo) { W ("ok        {0,-20} {1,3}s  {2}" -f $k, $s, $titulo) }
    elseif ($p.HasExited) { W ("FECHOU    {0,-20} saiu com codigo {1} sem abrir janela" -f $k, $p.ExitCode) }
    else { W ("SEMJANELA {0,-20} processo rodando, nenhuma janela em {1}s" -f $k, $Espera) }
    Get-Process | Where-Object { $_.Id -notin $antes -and $_.SessionId -eq $p.SessionId } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 3
}
W 'FIM'
