# Vigia o travamento da VM ao reiniciar (VirtualBox sobre Hyper-V): se o convidado ja desligou
# (ultimo evento "USB Suspended" sem "USB Operational" depois) e nao ha escrita em disco ha 3 min,
# aplica um reset. Encerra quando o agente sys reconecta ou apos -MaxMin minutos.
param([int]$MaxMin = 120, [string]$VM = 'EEEP-26H2')
$vb = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
$log = "C:\win11EEEP\vm\$VM\Logs\VBox.log"
$start = Get-Date; $resets = 0
while (((Get-Date) - $start).TotalMinutes -lt $MaxMin) {
    Start-Sleep 20
    $alive = Get-Item C:\win11EEEP\build\alive-sys.txt -ErrorAction SilentlyContinue
    if ($alive -and $alive.LastWriteTime -gt $start.AddSeconds(30)) { "agente sys reconectou as $($alive.LastWriteTime.ToString('HH:mm:ss')); resets aplicados: $resets"; exit 0 }
    $ev = Select-String -Path $log -Pattern 'xHCI: USB (Suspended|Operational)' | Select-Object -Last 1
    if (-not $ev -or $ev.Line -notmatch 'Suspended') { continue }
    $vdi = Get-ChildItem "C:\win11EEEP\vm\$VM\Snapshots\*.vdi", "C:\win11EEEP\vm\$VM\*.vdi" | Sort-Object LastWriteTime | Select-Object -Last 1
    if (((Get-Date) - $vdi.LastWriteTime).TotalMinutes -ge 3) {
        & $vb controlvm $VM reset; $resets++
        "$(Get-Date -Format HH:mm:ss) reset aplicado (travada apos desligar)"
        Start-Sleep 90
    }
}
"tempo esgotado; resets aplicados: $resets"
