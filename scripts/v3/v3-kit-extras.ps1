# v3 do zero, passo 2 (complemento do Install-LabSoftware): instaladores locais do kit (DVD EEEPKIT em D:\kit).
# Mesmos parametros dos jobs 54 (Extras), 30 (VDE-CE) e 33 (servicos do XAMPP) da montagem antiga.
$ErrorActionPreference = 'Continue'
$P = 'D:\kit\Pacotes'; $X = "$P\Extras"
$log = 'C:\ProgramData\EEEPBuild\v3-kit-extras.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
function Run($name, $file, $arguments, [int]$min = 30) {
    if (-not (Test-Path -LiteralPath $file) -and $file -ne 'msiexec.exe') { L "$name FALHA: arquivo nao encontrado: $file"; return }
    $p = Start-Process -FilePath $file -ArgumentList $arguments -PassThru
    if ($p.WaitForExit($min * 60000)) { L "$name exit=$($p.ExitCode)" } else { L "$name TIMEOUT ($min min)" }
}
$tmp = 'C:\ProgramData\EEEPBuild\tmp'; New-Item -ItemType Directory -Force $tmp | Out-Null

Run 'MySQL Workbench 8.0.36' 'msiexec.exe' @('/i', "`"$X\mysql-workbench-community-8.0.36-winx64.msi`"", '/qn', '/norestart', 'ALLUSERS=1')
Run 'Portugol Studio 2.7.5' "$X\portugol-studio-2.7.5-windows.exe" @('--mode', 'unattended', '--unattendedmodeui', 'none')
Run 'Dev-C++ 4.9.9.2' "$X\devcpp-4.9.9.2_setup.exe" @('/S')

# RustDesk 1.5.3 (instalador oficial do kit, assinatura PURSLANE): --silent-install instala para todos e cria o servico
Copy-Item "$P\rustdesk-1.5.3-x86_64.exe" "$tmp\rustdesk.exe" -Force
L "RustDesk: assinatura=$((Get-AuthenticodeSignature "$tmp\rustdesk.exe").Status) $((Get-AuthenticodeSignature "$tmp\rustdesk.exe").SignerCertificate.Subject)"
$p = Start-Process "$tmp\rustdesk.exe" -ArgumentList '--silent-install' -PassThru; [void]$p.WaitForExit(10 * 60000)
for ($i = 0; $i -lt 30 -and -not (Get-Service RustDesk -ErrorAction SilentlyContinue); $i++) { Start-Sleep 5 }
L "RustDesk: exe=$(Test-Path 'C:\Program Files\RustDesk\rustdesk.exe') servico=$((Get-Service RustDesk -ErrorAction SilentlyContinue).Status)"

# Agente VDE-CE
$p = Start-Process msiexec.exe -ArgumentList '/i', "`"$P\vde-ce-agente-0.8.1.msi`"", '/qn', '/norestart' -PassThru
[void]$p.WaitForExit(15 * 60000); L "VDE-CE Agente exit=$($p.ExitCode)"
Get-Process netmonitor-agent -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
L "VDE-CE: $(Test-Path 'C:\Program Files\VDE-CE\netmonitor-agent.exe')"

# XAMPP: Apache e MariaDB como servicos automaticos (igual ao job 33)
Get-Process httpd, mysqld, xampp-control -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
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

L '== conferencia'
$chk = [ordered]@{
    'MySQL Workbench' = 'C:\Program Files\MySQL\MySQL Workbench 8.0*\MySQLWorkbench.exe'
    'Portugol Studio' = 'C:\ProgramData\UNIVALI\Portugol Studio\*.exe'
    'Dev-C++'         = 'C:\Dev-Cpp\devcpp.exe'
    'RustDesk'        = 'C:\Program Files\RustDesk\rustdesk.exe'
    'VDE-CE'          = 'C:\Program Files\VDE-CE\netmonitor-agent.exe'
}
foreach ($k in $chk.Keys) { L ("{0,-16} {1}" -f $k, [bool](Get-Item $chk[$k] -ErrorAction SilentlyContinue)) }
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
