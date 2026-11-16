$ErrorActionPreference = 'SilentlyContinue'
$logs = Get-ChildItem 'C:\Users\Administrador\AppData\Local\Temp\install-postgresql.log', 'C:\Users\Administrador\AppData\Local\Temp\bitrock_installer*.log', 'C:\Windows\Temp\install-postgresql.log', 'C:\Users\Administrador\AppData\Local\Temp\postgresql_installer_*\*.log' | Sort-Object LastWriteTime
$logs | ForEach-Object { "$($_.FullName) | $($_.Length) | $($_.LastWriteTime.ToString('HH:mm:ss'))" }
$main = $logs | Where-Object { $_.Name -eq 'install-postgresql.log' } | Select-Object -Last 1
if ($main) { '--- erros/avisos:'; Select-String -LiteralPath $main.FullName -Pattern 'error|fail|problem|unable|denied|cannot|exit code|initcluster|Initiali|service' | Select-Object -Last 25 | ForEach-Object { $_.Line.Substring(0, [math]::Min(180, $_.Line.Length)) }; '--- final:'; Get-Content $main.FullName -Tail 12 | ForEach-Object { $_.Substring(0, [math]::Min(180, $_.Length)) } }
'--- estado:'
"data existe: $(Test-Path 'C:\Program Files\PostgreSQL\18\data\PG_VERSION')  itens em data: $(@(Get-ChildItem 'C:\Program Files\PostgreSQL\18\data').Count)"
Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'postgres|initdb|pg_ctl|getlocales|createuser|icacls|cscript|wscript' } | ForEach-Object { "$($_.Name) pid=$($_.ProcessId) inicio=$($_.CreationDate.ToString('HH:mm')) $(($_.CommandLine -replace '\s+',' ').Substring(0,[math]::Min(120,($_.CommandLine -replace '\s+',' ').Length)))" }
Get-ChildItem C:\ProgramData\EEEPBuild\*164131*  | Select-Object Name, Length, LastWriteTime
