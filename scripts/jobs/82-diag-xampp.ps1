$ErrorActionPreference = 'SilentlyContinue'
'--- C:\xampp:'; Get-ChildItem C:\xampp -Force | Select-Object Mode, LastWriteTime, Name | Format-Table -AutoSize | Out-String -Width 150
"itens totais: $(@(Get-ChildItem C:\xampp -Recurse -Force).Count)"
"php.exe: $(Test-Path C:\xampp\php\php.exe)  httpd.exe: $(Test-Path C:\xampp\apache\bin\httpd.exe)  mysqld.exe: $(Test-Path C:\xampp\mysql\bin\mysqld.exe)"
'--- servicos:'; Get-CimInstance Win32_Service -Filter "Name='Apache2.4' or Name='mysql'" | ForEach-Object { "$($_.Name) $($_.State) $($_.PathName)" }
'--- eventos recentes dos servicos:'
Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Service Control Manager'; StartTime = (Get-Date).AddHours(-4) } | Where-Object { $_.Message -match 'Apache|mysql' } | Select-Object -First 6 | ForEach-Object { "$($_.TimeCreated.ToString('HH:mm')) $($_.Message.Substring(0,[math]::Min(160,$_.Message.Length)))" }
'--- instaladores MSI recentes que mexeram em C:\xampp? (Application log, MsiInstaller):'
Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'MsiInstaller'; StartTime = (Get-Date).AddHours(-4) } | Select-Object -First 12 | ForEach-Object { "$($_.TimeCreated.ToString('HH:mm')) $($_.Message.Substring(0,[math]::Min(130,$_.Message.Length)))" }
'--- FluidSIM / Didactic:'; Get-ChildItem 'C:\Program Files (x86)\Didactic' -Recurse -Filter *.exe | Select-Object -First 5 FullName
"ACL Postman (Aluno): $((Get-Acl 'C:\Users\Aluno\AppData\Local\Postman\Postman.exe').Access | Where-Object { $_.IdentityReference -match 'Aluno' } | ForEach-Object { $_.FileSystemRights })"
"dono: $((Get-Acl 'C:\Users\Aluno\AppData\Local\Postman').Owner)"
