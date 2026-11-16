& powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\guest\Desativar-AvisosOOBE.ps1 2>&1
'--- conferencia (perfil do Administrador):'
$sid = (Get-LocalUser Administrador).SID.Value
reg query "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v ScoobeSystemSettingEnabled 2>&1 | Select-String Scoobe
reg query 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 2>&1 | Select-String Disable
