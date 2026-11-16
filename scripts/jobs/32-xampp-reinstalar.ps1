# O desinstalador do XAMPP 8.0.30 continuou rodando em segundo plano e apagou o XAMPP 8.2 recem-instalado.
# Reinstala o 8.2 numa pasta limpa e religa os servicos. Tambem corrige PATH do Nmap e atalhos quebrados.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\kit.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
$left = Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -like 'C:\xampp\*' -or $_.Name -match '^(uninstall|_uninstall|autorun)' }
$left | ForEach-Object { L "processo residual encerrado: $($_.Name) $($_.ExecutablePath)"; Stop-Process -Id $_.ProcessId -Force }
Stop-Service Apache2.4, mysql -Force -ErrorAction SilentlyContinue
$htdocs = 'C:\ProgramData\EEEPBuild\htdocs-bkp'
if (Test-Path C:\xampp\htdocs) { & robocopy.exe C:\xampp\htdocs $htdocs /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null }
cmd /c 'rd /s /q C:\xampp'
L "pasta C:\xampp limpa: $(-not (Test-Path C:\xampp))"
$inst = (Get-ChildItem 'D:\kit\Pacotes\WinGet\ApacheFriends.Xampp.8.2' -Filter '*.exe' | Select-Object -First 1).FullName
Copy-Item $inst 'C:\ProgramData\EEEPBuild\xampp-setup.exe' -Force
$p = Start-Process 'C:\ProgramData\EEEPBuild\xampp-setup.exe' -ArgumentList '--mode', 'unattended', '--unattendedmodeui', 'none' -PassThru
# o instalador abre dois terminais (cmd) no fim que so terminam quando fechados: fecha sozinho
$t0 = Get-Date
while (-not $p.HasExited -and ((Get-Date) - $t0).TotalMinutes -lt 45) {
    Get-CimInstance Win32_Process -Filter "Name='cmd.exe'" | Where-Object { $_.CommandLine -match 'xampp' } |
        ForEach-Object { L "terminal do instalador fechado: $($_.CommandLine)"; Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep 5
}
# o instalador do XAMPP pode deixar processos filhos terminando: espera esvaziar
for ($i = 0; $i -lt 120 -and (Get-Process | Where-Object { $_.Path -like 'C:\ProgramData\EEEPBuild\xampp*' -or $_.Path -like "$env:TEMP\*bitrock*" }); $i++) { Start-Sleep 5 }
Remove-Item 'C:\ProgramData\EEEPBuild\xampp-setup.exe' -Force -ErrorAction SilentlyContinue
L "XAMPP 8.2 exit=$($p.ExitCode) php=$(Test-Path C:\xampp\php\php.exe) httpd=$(Test-Path C:\xampp\apache\bin\httpd.exe) mysqld=$(Test-Path C:\xampp\mysql\bin\mysqld.exe)"
if (Test-Path $htdocs) { & robocopy.exe $htdocs C:\xampp\htdocs /E /XC /XN /XO /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null; Remove-Item $htdocs -Recurse -Force }
& icacls.exe C:\xampp /grant '*S-1-5-32-545:(OI)(CI)M' /T /C /Q | Out-Null
if (-not (Get-Service Apache2.4 -ErrorAction SilentlyContinue)) { & C:\xampp\apache\bin\httpd.exe -k install -n Apache2.4 2>&1 | Select-Object -Last 1 }
if (-not (Get-Service mysql -ErrorAction SilentlyContinue)) { & C:\xampp\mysql\bin\mysqld.exe --install mysql --defaults-file=C:\xampp\mysql\bin\my.ini 2>&1 | Select-Object -Last 1 }
foreach ($s in 'Apache2.4', 'mysql') { Set-Service $s -StartupType Automatic; Start-Service $s -ErrorAction Continue }
Start-Sleep 8
L ((Get-Service Apache2.4, mysql | ForEach-Object { "$($_.Name)=$($_.Status)/$($_.StartType)" }) -join ' ')
try { L "http://localhost/dashboard/ -> $((Invoke-WebRequest -UseBasicParsing http://localhost/dashboard/ -TimeoutSec 20).StatusCode)" } catch { L "teste HTTP falhou: $($_.Exception.Message)" }
$c = New-Object Net.Sockets.TcpClient; try { $c.Connect('127.0.0.1', 3306); L 'MariaDB porta 3306 ok' } catch { L 'MariaDB porta 3306 FECHADA' } finally { $c.Close() }

# Nmap no PATH da maquina
$nm = 'C:\Program Files (x86)\Nmap'
$mp = [Environment]::GetEnvironmentVariable('Path', 'Machine')
if ((Test-Path "$nm\nmap.exe") -and ($mp -split ';') -notcontains $nm) { [Environment]::SetEnvironmentVariable('Path', "$mp;$nm", 'Machine'); L 'PATH += Nmap' }
# atalhos quebrados no perfil do Administrador
$w = New-Object -ComObject WScript.Shell
foreach ($l in Get-ChildItem 'C:\Users\*\Desktop\*.lnk') {
    $t = $w.CreateShortcut($l.FullName).TargetPath
    if ($t -and $t -match '^[A-Z]:\\' -and -not (Test-Path -LiteralPath $t)) { Remove-Item $l.FullName -Force; L "atalho quebrado removido: $($l.FullName)" }
}
