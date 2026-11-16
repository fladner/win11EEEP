param(
    [string]$Name = 'EEEP-Teste',
    [string]$Iso  = 'C:\win11EEEP\Win11Pro_26H2_EEEP.iso',
    [string]$Dir  = 'C:\win11EEEP\vm\teste'
)
# VM limpa (UEFI, TPM 2.0, Secure Boot) para testar a ISO final como um PC novo.
$ErrorActionPreference = 'Stop'
$vbm = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
if (-not (Test-Path $Iso)) { throw "ISO nao encontrada: $Iso" }
New-Item -ItemType Directory -Force $Dir | Out-Null
$vdi = Join-Path $Dir "$Name.vdi"

& $vbm createvm --name $Name --ostype Windows11_64 --basefolder $Dir --register
& $vbm modifyvm $Name --firmware efi --tpm-type 2.0 --cpus 8 --memory 16384 --vram 128 `
    --graphicscontroller vboxsvga --nic1 nat --audio-driver none --usb-xhci on --mouse usbtablet
& $vbm createmedium disk --filename $vdi --size 225280 --format VDI
& $vbm storagectl $Name --name SATA --add sata --controller IntelAhci --portcount 4
& $vbm storageattach $Name --storagectl SATA --port 0 --device 0 --type hdd --medium $vdi
& $vbm storageattach $Name --storagectl SATA --port 1 --device 0 --type dvddrive --medium $Iso
& $vbm modifynvram $Name inituefivarstore
& $vbm modifynvram $Name enrollmssignatures
& $vbm modifynvram $Name enrollorclpk
& $vbm startvm $Name --type gui
