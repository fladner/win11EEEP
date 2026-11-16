# Instala todas as atualizacoes do Windows Update, exceto drivers.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\wu.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
$s = New-Object -ComObject Microsoft.Update.Session
$r = $s.CreateUpdateSearcher().Search("IsInstalled=0 and IsHidden=0")
$col = New-Object -ComObject Microsoft.Update.UpdateColl
foreach ($u in $r.Updates) {
    $isDriver = @($u.Categories | Where-Object { $_.Name -eq 'Drivers' }).Count -gt 0
    if ($isDriver) { L "pulado (driver): $($u.Title)"; continue }
    if (-not $u.EulaAccepted) { $u.AcceptEula() }
    [void]$col.Add($u); L "selecionado: $($u.Title)"
}
if ($col.Count -eq 0) { L 'nada a instalar'; return }
$d = $s.CreateUpdateDownloader(); $d.Updates = $col
L 'baixando...'; $dr = $d.Download(); L "download resultado=$($dr.ResultCode) hr=0x$('{0:X8}' -f $dr.HResult)"
$i = $s.CreateUpdateInstaller(); $i.Updates = $col
L 'instalando...'; $ir = $i.Install()
for ($k = 0; $k -lt $col.Count; $k++) { $x = $ir.GetUpdateResult($k); L ("{0} -> resultado={1} hr=0x{2:X8}" -f $col.Item($k).Title, $x.ResultCode, $x.HResult) }
L "geral resultado=$($ir.ResultCode) reinicio=$($ir.RebootRequired)   (2=ok 3=ok com erros 4=falha)"
