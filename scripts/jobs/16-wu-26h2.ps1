# Instala pelo Windows Update a atualizacao de recurso "Windows 11, version 26H2".
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\wu.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
$s = New-Object -ComObject Microsoft.Update.Session
$r = $s.CreateUpdateSearcher().Search("IsInstalled=0 and Type='Software'")
$col = New-Object -ComObject Microsoft.Update.UpdateColl
foreach ($u in $r.Updates) {
    if ($u.Title -match '26H2' -and @($u.Categories | Where-Object { $_.Name -eq 'Upgrades' }).Count) {
        if (-not $u.EulaAccepted) { $u.AcceptEula() }
        [void]$col.Add($u); L "selecionado: $($u.Title)"
    } else { L "ignorado: $($u.Title)" }
}
if ($col.Count -eq 0) { L 'atualizacao 26H2 nao oferecida'; return }
$d = $s.CreateUpdateDownloader(); $d.Updates = $col
L 'baixando 26H2...'; $dr = $d.Download(); L ("download resultado={0} hr=0x{1:X8}" -f $dr.ResultCode, $dr.HResult)
$i = $s.CreateUpdateInstaller(); $i.Updates = $col
L 'instalando 26H2...'; $ir = $i.Install()
L ("resultado={0} hr=0x{1:X8} reinicio={2}   (2=ok 3=ok com erros 4=falha)" -f $ir.ResultCode, $ir.HResult, $ir.RebootRequired)
