# Desliga a VM pelo Windows convidado e aguarda. Se travar apos o Windows encerrar
# (limitacao do VirtualBox sobre Hyper-V), forca o desligamento.
param([string]$VM = 'EEEP-26H2', [int]$MaxMin = 20)
$vb = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
$log = "C:\win11EEEP\vm\$VM\Logs\VBox.log"
$job = Join-Path $env:TEMP 'eeep-desligar.ps1'
Set-Content $job "shutdown.exe /s /t 5 /c `"EEEP build: desligando`"; 'desligamento agendado'" -Encoding ASCII
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\win11EEEP\scripts\host\Run-Guest.ps1 -Agent sys -File $job -TimeoutSec 90
$t0 = Get-Date
while (((Get-Date) - $t0).TotalMinutes -lt $MaxMin) {
    Start-Sleep 10
    $st = (& $vb showvminfo $VM --machinereadable | Select-String '^VMState=').Line
    if ($st -match 'poweroff|aborted') { "VM desligada: $st"; exit 0 }
    $ev = Select-String -Path $log -Pattern 'xHCI: USB (Suspended|Operational)' | Select-Object -Last 1
    $vdi = Get-ChildItem "C:\win11EEEP\vm\$VM\Snapshots\*.vdi" | Sort-Object LastWriteTime | Select-Object -Last 1
    if ($ev -and $ev.Line -match 'Suspended' -and ((Get-Date) - $vdi.LastWriteTime).TotalMinutes -ge 2) {
        & $vb controlvm $VM poweroff; Start-Sleep 5
        "desligamento forcado apos o Windows encerrar: $((& $vb showvminfo $VM --machinereadable | Select-String '^VMState=').Line)"; exit 0
    }
}
"tempo esgotado; estado: $st"
