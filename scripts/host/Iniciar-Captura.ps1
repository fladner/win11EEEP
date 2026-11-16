# Prepara a VM para capturar a imagem generalizada pelo WinPE da ISO oficial.
$vb = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'; $vm = 'EEEP-26H2'
& $vb snapshot $vm take 'pos-sysprep' --description 'Imagem generalizada (sysprep /oobe). NAO dar boot pelo disco antes de capturar.' 2>&1 | Select-Object -Last 1
$cap = 'C:\win11EEEP\vm\captura\captura.vdi'
New-Item -ItemType Directory -Force (Split-Path $cap) | Out-Null
if (-not (Test-Path $cap)) { & $vb createmedium disk --filename $cap --size 307200 --format VDI --variant Standard 2>&1 | Select-Object -Last 1 }
& $vb storagectl $vm --name SATA --portcount 4
& $vb storageattach $vm --storagectl SATA --port 2 --device 0 --type hdd --medium $cap --nonrotational on
& $vb storageattach $vm --storagectl SATA --port 1 --device 0 --type dvddrive --medium 'C:\win11EEEP\Windows11_Client_x64_pt-br_26300_9457.iso'
& $vb storageattach $vm --storagectl SATA --port 3 --device 0 --type dvddrive --medium 'C:\win11EEEP\build\cap.viso'
& $vb modifyvm $vm --boot1 dvd --boot2 none --boot3 none --boot4 none --nic1 null
& $vb showvminfo $vm --machinereadable | Select-String '^"SATA-\d-0"|^boot1|^nic1'
& $vb startvm $vm --type gui 2>&1 | Select-Object -Last 1
# "Pressione qualquer tecla para iniciar do CD/DVD"
for ($i = 0; $i -lt 30; $i++) { Start-Sleep -Milliseconds 700; & $vb controlvm $vm keyboardputscancode 39 b9 2>$null }
'teclas enviadas para dar boot pelo DVD'
