# PostgreSQL 18 (servidor, pgAdmin e ferramentas de linha de comando), por maquina.
# A senha da conta postgres e digitada pelo tecnico numa janela na VM; nao fica em arquivo nem em log.
# Rodar como Administrador (agente user), com a sessao do Administrador aberta na VM.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\kit.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
if (Get-Service postgresql-x64-18 -ErrorAction SilentlyContinue) { L 'PostgreSQL 18 ja instalado'; return }
$inst = (Get-ChildItem 'D:\kit\Pacotes\WinGet\PostgreSQL.PostgreSQL.18' -Filter '*.exe' | Select-Object -First 1).FullName
if (-not $inst) { L 'FALHA: instalador do PostgreSQL 18 nao encontrado no kit'; return }
Add-Type -AssemblyName Microsoft.VisualBasic
$pw = ''
for ($i = 0; $i -lt 3 -and -not $pw; $i++) {
    $a = [Microsoft.VisualBasic.Interaction]::InputBox('Digite a senha da conta postgres do PostgreSQL 18:', 'EEEP - PostgreSQL 18', '')
    $b = [Microsoft.VisualBasic.Interaction]::InputBox('Repita a senha da conta postgres:', 'EEEP - PostgreSQL 18', '')
    if ($a -and $a -ceq $b) { $pw = $a } else { [void][Microsoft.VisualBasic.Interaction]::MsgBox('As senhas estao vazias ou nao conferem. Tente de novo.', 'OKOnly', 'EEEP') }
}
if (-not $pw) { L 'FALHA: senha do postgres nao informada'; return }
if (Test-Path 'C:\Program Files\PostgreSQL\18\data') { Rename-Item 'C:\Program Files\PostgreSQL\18\data' ("data-antiga-{0:yyyyMMddHHmm}" -f (Get-Date)) }
# mesmo formato do kit: arquivo de opcoes sem BOM (com BOM o instalador abre a interface grafica), apagado em seguida
$opt = Join-Path $env:TEMP ("pg18-{0}.ini" -f [guid]::NewGuid().ToString('N'))
$lines = @('mode=unattended', 'unattendedmodeui=none', 'superaccount=postgres', "superpassword=$pw", 'serverport=5432', 'disable-components=stackbuilder')
[IO.File]::WriteAllLines($opt, $lines, (New-Object Text.UTF8Encoding $false))
$pw = $null; $lines = $null
try {
    $p = Start-Process $inst -ArgumentList '--mode', 'unattended', '--unattendedmodeui', 'none', '--optionfile', "`"$opt`"" -PassThru
    if ($p.WaitForExit(60 * 60000)) { L "PostgreSQL 18 exit=$($p.ExitCode)" } else { L 'PostgreSQL 18 TIMEOUT' }
} finally { Remove-Item $opt -Force -ErrorAction SilentlyContinue }
$il = Get-ChildItem $env:TEMP, 'C:\Windows\Temp' -Filter 'install-postgresql*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
if ($il) { L "log do instalador: $($il.FullName)"; Get-Content $il.FullName -Tail 8 | Where-Object { $_ -notmatch 'password' } | ForEach-Object { L "   $_" } }
$bin = 'C:\Program Files\PostgreSQL\18\bin'
$mp = [Environment]::GetEnvironmentVariable('Path', 'Machine')
if ((Test-Path "$bin\psql.exe") -and ($mp -split ';') -notcontains $bin) { [Environment]::SetEnvironmentVariable('Path', "$mp;$bin", 'Machine'); L 'PATH += PostgreSQL 18\bin' }
L "servico: $((Get-Service postgresql-x64-18 -ErrorAction SilentlyContinue | ForEach-Object { "$($_.Status)/$($_.StartType)" }))"
L "pgAdmin: $(Test-Path 'C:\Program Files\PostgreSQL\18\pgAdmin 4\runtime\pgAdmin4.exe')"
