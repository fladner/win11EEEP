# Substitui o XAMPP 8.0.30 pelo 8.2.12 e registra Apache e MariaDB como servicos automaticos.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\kit.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
Get-Process httpd, mysqld, xampp-control -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$ver = (Select-String -Path C:\xampp\properties.ini -Pattern 'base_stack_version=(.+)' -ErrorAction SilentlyContinue).Matches.Groups[1].Value
L "XAMPP atual: $ver"
if ($ver -and $ver -notlike '8.2*') {
    if (Test-Path C:\xampp\uninstall.exe) {
        $p = Start-Process C:\xampp\uninstall.exe -ArgumentList '--mode', 'unattended', '--unattendedmodeui', 'none' -PassThru
        [void]$p.WaitForExit(30 * 60000); L "remocao do XAMPP antigo exit=$($p.ExitCode)"; Start-Sleep 15
    }
    if (Test-Path C:\xampp) { Remove-Item C:\xampp -Recurse -Force -ErrorAction SilentlyContinue; L "pasta antiga removida: $(-not (Test-Path C:\xampp))" }
}
if (-not (Test-Path C:\xampp\xampp-control.exe)) {
    $inst = (Get-ChildItem 'D:\kit\Pacotes\WinGet\ApacheFriends.Xampp.8.2' -Filter '*.exe' | Select-Object -First 1).FullName
    $p = Start-Process $inst -ArgumentList '--mode', 'unattended', '--unattendedmodeui', 'none' -PassThru
    if ($p.WaitForExit(45 * 60000)) { L "XAMPP 8.2 exit=$($p.ExitCode)" } else { L 'XAMPP 8.2 TIMEOUT' }
}
if (-not (Test-Path C:\xampp\apache\bin\httpd.exe)) { L 'FALHA: XAMPP nao instalado'; return }
& icacls.exe C:\xampp /grant '*S-1-5-32-545:(OI)(CI)M' /T /C /Q | Out-Null
foreach ($d in 'C:\xampp\php', 'C:\xampp\mysql\bin') {
    $mp = [Environment]::GetEnvironmentVariable('Path', 'Machine'); if (($mp -split ';') -notcontains $d) { [Environment]::SetEnvironmentVariable('Path', "$mp;$d", 'Machine') }
}
# Servicos
if (-not (Get-Service Apache2.4 -ErrorAction SilentlyContinue)) { & C:\xampp\apache\bin\httpd.exe -k install -n Apache2.4 2>&1 | Select-Object -Last 2 }
if (-not (Get-Service mysql -ErrorAction SilentlyContinue)) { & C:\xampp\mysql\bin\mysqld.exe --install mysql --defaults-file=C:\xampp\mysql\bin\my.ini 2>&1 | Select-Object -Last 2 }
foreach ($s in 'Apache2.4', 'mysql') { Set-Service $s -StartupType Automatic; Start-Service $s -ErrorAction Continue }
Start-Sleep 8
L ((Get-Service Apache2.4, mysql | ForEach-Object { "$($_.Name)=$($_.Status)/$($_.StartType)" }) -join ' ')
L ("portas: " + ((Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -in 80, 443, 3306 } | ForEach-Object { "$($_.LocalPort)" } | Sort-Object -Unique) -join ','))
try { $r = Invoke-WebRequest -UseBasicParsing http://localhost/dashboard/ -TimeoutSec 20; L "http://localhost/dashboard/ -> $($r.StatusCode)" } catch { L "teste HTTP falhou: $($_.Exception.Message)" }
