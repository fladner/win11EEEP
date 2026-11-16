$ErrorActionPreference = 'Continue'
"== Politicas de maquina (Registry.pol):"
$b = [IO.File]::ReadAllBytes('C:\Windows\System32\GroupPolicy\Machine\Registry.pol'); ([Text.Encoding]::Unicode.GetString($b) -replace '[^\x20-\x7e]+', ' ')
"== Politicas de usuario (Registry.pol):"
$b = [IO.File]::ReadAllBytes('C:\Windows\System32\GroupPolicy\User\Registry.pol'); ([Text.Encoding]::Unicode.GetString($b) -replace '[^\x20-\x7e]+', ' ')
"== Chaves WindowsUpdate:"
reg query 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /s 2>&1 | Out-String
(Get-Service wuauserv, UsoSvc, BITS, DoSvc | Select-Object Name, Status, StartType | Out-String).Trim()
"== Busca de atualizacoes:"
$s = New-Object -ComObject Microsoft.Update.Session
$r = $s.CreateUpdateSearcher().Search("IsInstalled=0 and IsHidden=0")
foreach ($u in $r.Updates) { '{0} | {1:N0} MB | {2}' -f $u.Title, ($u.MaxDownloadSize / 1MB), (($u.Categories | ForEach-Object Name) -join ',') }
"total: $($r.Updates.Count)"
