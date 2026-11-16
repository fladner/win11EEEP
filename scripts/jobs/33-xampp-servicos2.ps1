# Registra Apache e MariaDB do XAMPP 8.2 como servicos automaticos e testa (quando o 32 instalou, mas os servicos nao existiam).
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\kit.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
Get-Process httpd, mysqld, xampp-control -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$ver = (Select-String -Path C:\xampp\properties.ini -Pattern 'base_stack_version=(.+)' -ErrorAction SilentlyContinue).Matches.Groups[1].Value
L "XAMPP: $ver"
if (-not (Get-Service Apache2.4 -ErrorAction SilentlyContinue)) { (& C:\xampp\apache\bin\httpd.exe -k install -n Apache2.4 2>&1 | Select-Object -Last 2) | ForEach-Object { L "httpd: $_" } }
if (-not (Get-Service mysql -ErrorAction SilentlyContinue)) { (& C:\xampp\mysql\bin\mysqld.exe --install mysql --defaults-file=C:\xampp\mysql\bin\my.ini 2>&1 | Select-Object -Last 2) | ForEach-Object { L "mysqld: $_" } }
foreach ($s in 'Apache2.4', 'mysql') { Set-Service $s -StartupType Automatic -ErrorAction Continue; Start-Service $s -ErrorAction Continue }
& icacls.exe C:\xampp /grant '*S-1-5-32-545:(OI)(CI)M' /T /C /Q | Out-Null
foreach ($d in 'C:\xampp\php', 'C:\xampp\mysql\bin') {
    $mp = [Environment]::GetEnvironmentVariable('Path', 'Machine'); if (($mp -split ';') -notcontains $d) { [Environment]::SetEnvironmentVariable('Path', "$mp;$d", 'Machine'); L "PATH += $d" }
}
Start-Sleep 8
L ((Get-Service Apache2.4, mysql -ErrorAction SilentlyContinue | ForEach-Object { "$($_.Name)=$($_.Status)/$($_.StartType)" }) -join ' ')
try { L "http://localhost/dashboard/ -> $((Invoke-WebRequest -UseBasicParsing http://localhost/dashboard/ -TimeoutSec 20).StatusCode)" } catch { L "teste HTTP falhou: $($_.Exception.Message)" }
$c = New-Object Net.Sockets.TcpClient; try { $c.Connect('127.0.0.1', 3306); L 'MariaDB porta 3306 ok' } catch { L 'MariaDB porta 3306 FECHADA' } finally { $c.Close() }
