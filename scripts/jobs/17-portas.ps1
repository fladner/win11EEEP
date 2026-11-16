$ErrorActionPreference = 'SilentlyContinue'
"whoami: $(whoami)"
'--- servicos web/banco:'
(Get-Service W3SVC, WAS, MySQL*, MariaDB*, Apache*, postgresql*, MSSQL*, Tomcat*, FileZilla* | Select-Object Name, DisplayName, Status, StartType | Format-Table -AutoSize | Out-String -Width 200).Trim()
'--- quem escuta em 80, 443, 3306, 5432, 8080:'
Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -in 80, 443, 3306, 3307, 5432, 8080, 33060 } | ForEach-Object { '{0}:{1} pid={2} {3}' -f $_.LocalAddress, $_.LocalPort, $_.OwningProcess, (Get-Process -Id $_.OwningProcess).ProcessName }
'--- IIS instalado?'
(Get-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole | Select-Object FeatureName, State | Out-String).Trim()
Get-ChildItem C:\inetpub | Select-Object Name
'--- XAMPP atual:'
Get-Content C:\xampp\properties.ini | Select-String 'base_stack_version|apache_server_port|mysql_port'
Select-String -Path C:\xampp\apache\conf\httpd.conf -Pattern '^Listen ' | ForEach-Object Line
Select-String -Path C:\xampp\mysql\bin\my.ini -Pattern '^port' | ForEach-Object Line
'htdocs:'; Get-ChildItem C:\xampp\htdocs | Select-Object Name, LastWriteTime
'bancos do XAMPP:'; Get-ChildItem C:\xampp\mysql\data -Directory | Select-Object Name
'--- MySQL 8.0 (servico):'
Select-String -Path 'C:\ProgramData\MySQL\MySQL Server 8.0\my.ini' -Pattern '^port' | ForEach-Object Line
'bancos MySQL 8.0:'; Get-ChildItem 'C:\ProgramData\MySQL\MySQL Server 8.0\Data' -Directory | Select-Object Name
'--- drivers DAEMON Tools:'
(Get-CimInstance Win32_SystemDriver | Where-Object { $_.Name -match 'dtlite' } | Select-Object Name, State | Out-String).Trim()
