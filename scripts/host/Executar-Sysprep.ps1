# Desliga a VM, tira snapshot "pre-sysprep", religa, espera o agente e executa o sysprep (que desliga a VM).
$vb = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'; $vm = 'EEEP-26H2'; $h = 'C:\win11EEEP\scripts\host'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$h\Desligar-VM.ps1"
& $vb snapshot $vm take 'pre-sysprep' --description 'Tudo instalado, limpo e preparado; antes do sysprep /generalize' 2>&1 | Select-Object -Last 1
$t = Get-Date; Start-Sleep 2
& $vb startvm $vm --type gui 2>&1 | Select-Object -Last 1
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$h\Aguardar-Agente.ps1" -Agent sys -MaxMin 20
Start-Sleep 60
"sysprep iniciado $(Get-Date -Format HH:mm:ss)"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$h\Run-Guest.ps1" -Agent sys -File C:\win11EEEP\scripts\jobs\71-sysprep.ps1 -TimeoutSec 60 | Out-Null
$t0 = Get-Date
while (((Get-Date) - $t0).TotalMinutes -lt 60) {
    Start-Sleep 15
    $st = (& $vb showvminfo $vm --machinereadable | Select-String '^VMState=').Line
    if ($st -match 'poweroff|aborted') { "VM desligada pelo sysprep apos $([int]((Get-Date)-$t0).TotalMinutes) min ($st)"; exit 0 }
    $r = Get-ChildItem C:\win11EEEP\build\results\*sys.txt | Where-Object { $_.LastWriteTime -gt $t0 -and (Select-String -LiteralPath $_.FullName -Pattern 'sysprep terminou sem desligar' -Quiet) } | Select-Object -First 1
    if ($r) { 'SYSPREP FALHOU:'; Get-Content $r.FullName; exit 2 }
}
"tempo esgotado; estado: $st"
