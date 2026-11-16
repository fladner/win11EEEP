$ErrorActionPreference = 'Continue'
$root = 'C:\Program Files\PostgreSQL\17'
"antes:"; (Get-Service postgresql* | Select-Object Name, Status | Out-String).Trim()
"data dir GB: " + [math]::Round(((Get-ChildItem "$root\data" -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB), 2)
Get-Service postgresql* | Stop-Service -Force -ErrorAction SilentlyContinue
$un = Join-Path $root 'uninstall-postgresql.exe'
if (Test-Path $un) {
    $p = Start-Process $un -ArgumentList '--mode', 'unattended', '--unattendedmodeui', 'none' -PassThru -Wait
    "uninstall exit=$($p.ExitCode)"
    Start-Sleep 20
} else { 'desinstalador nao encontrado' }
if (Test-Path $root) { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
if ((Test-Path 'C:\Program Files\PostgreSQL') -and -not (Get-ChildItem 'C:\Program Files\PostgreSQL' -Force)) { Remove-Item 'C:\Program Files\PostgreSQL' -Force }
Remove-Item 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\PostgreSQL 17' -Recurse -Force -ErrorAction SilentlyContinue
"depois: pasta existe=$(Test-Path $root)"; (Get-Service postgresql* -ErrorAction SilentlyContinue | Select-Object Name, Status | Out-String).Trim()
reg query 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' /s /f 'PostgreSQL' /d 2>&1 | Select-String 'DisplayName'
