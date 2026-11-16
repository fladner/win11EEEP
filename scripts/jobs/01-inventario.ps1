$ErrorActionPreference = 'SilentlyContinue'
"== whoami: $(whoami)"
$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
"== Windows: $($cv.ProductName) $($cv.DisplayVersion) build $($cv.CurrentBuild).$($cv.UBR) edicao $($cv.EditionID)"
"== Estado da imagem: $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State').ImageState)"
"== Disco C: livre GB: $([math]::Round((Get-PSDrive C).Free/1GB,1)) usado GB: $([math]::Round((Get-PSDrive C).Used/1GB,1))"
"== Rede: $((Test-NetConnection www.microsoft.com -Port 443 -WarningAction SilentlyContinue).TcpTestSucceeded)"
"== Ativacao:"; (Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f'" | Select-Object Name, LicenseStatus | Out-String).Trim()
"== Usuarios locais:"; (Get-LocalUser | Select-Object Name, Enabled, SID, PasswordRequired, PasswordExpires | Format-Table -AutoSize | Out-String).Trim()
"== Administradores:"; (Get-LocalGroupMember -SID S-1-5-32-544 | Select-Object Name | Out-String).Trim()
"== setupcomplete.cmd:"; Get-Content C:\Windows\Setup\Scripts\setupcomplete.cmd
"== Panther unattend:"; Get-ChildItem C:\Windows\Panther\*.xml, C:\Windows\System32\Sysprep\*.xml | Select-Object FullName, Length
"== GPO local:"; Get-ChildItem C:\Windows\System32\GroupPolicy, C:\Windows\System32\GroupPolicyUsers -Recurse -Force | Select-Object FullName, Length | Format-Table -AutoSize | Out-String -Width 200
"== winget:"; (Get-AppxPackage -AllUsers Microsoft.DesktopAppInstaller | Select-Object Version | Out-String).Trim()
"== Programas instalados:"
$keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
Get-ItemProperty $keys | Where-Object { $_.DisplayName -and -not $_.SystemComponent -and -not $_.ParentKeyName } |
    Sort-Object DisplayName -Unique | ForEach-Object { '{0} | {1} | {2}' -f $_.DisplayName, $_.DisplayVersion, $_.Publisher }
"== AnyDesk conf:"; Get-ChildItem C:\ProgramData\AnyDesk -Force | Select-Object Name, Length
Get-Content C:\ProgramData\AnyDesk\system.conf, C:\ProgramData\AnyDesk\service.conf | ForEach-Object { ($_ -split '=')[0] } | Sort-Object -Unique
"== RustDesk conf:"; Get-ChildItem 'C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config' -Force | Select-Object Name, Length
Get-Content 'C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml', 'C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml' | ForEach-Object { ($_ -split '=')[0].Trim() } | Sort-Object -Unique
"== Servicos AnyDesk/RustDesk:"; (Get-Service *anydesk*, *rustdesk* | Select-Object Name, Status, StartType | Out-String).Trim()
