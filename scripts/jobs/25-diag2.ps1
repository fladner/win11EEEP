$ErrorActionPreference = 'SilentlyContinue'
Get-Date -Format HH:mm:ss
'--- kit.log (linhas com exit/FALHA/TIMEOUT/JAVA):'
Get-Content C:\ProgramData\EEEPBuild\kit.log | Select-String 'exit=|FALHA|TIMEOUT|JAVA_HOME|presente|Revit|OK' | ForEach-Object { $_.Line.Substring(0, [math]::Min(150, $_.Line.Length)) }
'--- JDK:'; Get-ChildItem 'C:\Program Files\Eclipse Adoptium', 'C:\Program Files\Java' | Select-Object FullName
"JAVA_HOME=$([Environment]::GetEnvironmentVariable('JAVA_HOME','Machine'))"
'--- PostgreSQL:'; (Get-Service postgresql* | Select-Object Name, Status, StartType | Out-String).Trim()
"psql18: $(Test-Path 'C:\Program Files\PostgreSQL\18\bin\psql.exe')  porta 5432: $([bool](Get-NetTCPConnection -State Listen -LocalPort 5432))"
'--- processos de instalacao:'
Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'postgresql|Setup|Installer|msiexec|install|AdskAccess|adsso|Revit' -and $_.Name -notmatch 'TrustedInstaller' } | ForEach-Object { '{0} pid={1} inicio={2} {3}' -f $_.Name, $_.ProcessId, $_.CreationDate.ToString('HH:mm'), ($_.CommandLine -replace '\s+', ' ').Substring(0, [math]::Min(110, ($_.CommandLine -replace '\s+', ' ').Length)) }
'--- janelas:'; Get-Process | Where-Object { $_.MainWindowTitle } | ForEach-Object { "$($_.ProcessName) | $($_.MainWindowTitle)" }
"C: livre GB: $([math]::Round((Get-PSDrive C).Free/1GB,1))"
