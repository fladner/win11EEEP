$ErrorActionPreference = 'SilentlyContinue'
Get-Date -Format HH:mm:ss
Get-Content C:\ProgramData\EEEPBuild\wu.log | Select-Object -Last 4
'Download GB: ' + [math]::Round(((Get-ChildItem C:\Windows\SoftwareDistribution\Download -Recurse -Force | Measure-Object Length -Sum).Sum / 1GB), 2)
'--- processos de instalacao'
Get-CimInstance Win32_Process | Where-Object { $_.Name -match '_uninstall|uninstall|msiexec|TiWorker|setup|postgres|pg_ctl|install' } | ForEach-Object { '{0} pid={1} pai={2} inicio={3} cmd={4}' -f $_.Name, $_.ProcessId, $_.ParentProcessId, $_.CreationDate.ToString('HH:mm:ss'), ($_.CommandLine -replace '\s+', ' ') }
'--- PostgreSQL'
(Get-Service postgresql* | Select-Object Name, Status | Out-String).Trim()
'pasta 17 existe: ' + (Test-Path 'C:\Program Files\PostgreSQL\17')
'itens restantes: ' + (Get-ChildItem 'C:\Program Files\PostgreSQL\17' -Recurse -Force | Measure-Object).Count
'--- janelas visiveis'
Get-Process | Where-Object { $_.MainWindowTitle } | ForEach-Object { '{0} | {1}' -f $_.ProcessName, $_.MainWindowTitle }
