# Monta a ISO final: instalador da ISO oficial do Windows 11 26H2 + install.wim capturado da VM EEEP.
param(
    [string]$OfficialIso = 'C:\win11EEEP\Windows11_Client_x64_pt-br_26300_9457.iso',
    [string]$CaptureVdi = 'C:\win11EEEP\vm\captura\captura.vdi',
    [string]$Work = 'C:\win11EEEP\build\iso',
    [string]$Out = 'C:\win11EEEP\Win11Pro_26H2_EEEP.iso',
    [switch]$ReusarInstalador   # reaproveita os arquivos da ISO oficial ja extraidos em $Work
)
$ErrorActionPreference = 'Stop'
$z = 'C:\Program Files\7-Zip\7z.exe'
$oscdimg = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter oscdimg.exe | Select-Object -First 1).FullName

if ($ReusarInstalador -and (Test-Path "$Work\sources\boot.wim")) {
    "[1] reaproveitando o instalador ja extraido em $Work"
} else {
    "[1] extraindo a ISO oficial $(Get-Date -Format HH:mm:ss)"
    if (Test-Path $Work) { cmd /c "rd /s /q `"$Work`"" }
    & $z x $OfficialIso "-o$Work" -y -bso0 -bsp0; if ($LASTEXITCODE) { throw "7z ISO exit=$LASTEXITCODE" }
}
Remove-Item "$Work\sources\install.wim", "$Work\sources\install.esd" -Force -ErrorAction SilentlyContinue

"[2] extraindo install.wim do disco de captura $(Get-Date -Format HH:mm:ss)"
$list = & $z l $CaptureVdi -ba 2>&1
"conteudo do disco de captura:"; $list | Select-Object -First 10
$part = ($list | Where-Object { $_ -match '\s(\S+\.(ntfs|img))\s*$' } | ForEach-Object { $Matches[1] } | Select-Object -First 1)
$tmp = 'C:\win11EEEP\build\captura-x'
if (Test-Path $tmp) { cmd /c "rd /s /q `"$tmp`"" }
if ($part) {
    & $z e $CaptureVdi $part "-o$tmp" -y -bso0 -bsp0
    $img = Get-ChildItem $tmp -File | Select-Object -First 1
    & $z e $img.FullName 'install.wim' 'captura.log' 'dism-captura.log' 'winre-fix.log' "-o$Work\sources" -y -bso0 -bsp0
    Remove-Item $img.FullName -Force
} else {
    & $z e $CaptureVdi 'install.wim' 'captura.log' 'dism-captura.log' 'winre-fix.log' "-o$Work\sources" -r -y -bso0 -bsp0
}
if (-not (Test-Path "$Work\sources\install.wim")) { throw 'install.wim nao extraido' }
Move-Item "$Work\sources\captura.log", "$Work\sources\dism-captura.log", "$Work\sources\winre-fix.log" 'C:\win11EEEP\build\' -Force -ErrorAction SilentlyContinue
# o instalador do 26H2 extrai \Windows\System32\Recovery\Winre.wim do install.wim: sem ele a instalacao falha (0x80070003)
# (com um so indice o 7-Zip lista os caminhos sem o prefixo "1\")
$winre = & $z l "$Work\sources\install.wim" 'Windows\System32\Recovery\Winre.wim' '1\Windows\System32\Recovery\Winre.wim' -ba 2>$null
if (-not ($winre -match 'Winre\.wim')) { throw 'install.wim sem Windows\System32\Recovery\Winre.wim: rode scripts\capture\winre-fix.cmd no WinPE' }
"Winre.wim presente na imagem"
"install.wim: $([math]::Round((Get-Item "$Work\sources\install.wim").Length/1GB,2)) GB"
Get-Content C:\win11EEEP\build\captura.log -ErrorAction SilentlyContinue

"[3] ei.cfg e gerando a ISO $(Get-Date -Format HH:mm:ss)"
Set-Content "$Work\sources\ei.cfg" "[EditionID]`r`nProfessional`r`n[Channel]`r`nRetail`r`n[VL]`r`n0" -Encoding ASCII
$boot = "2#p0,e,b$Work\boot\etfsboot.com#pEF,e,b$Work\efi\microsoft\boot\efisys.bin"
& $oscdimg -m -o -u2 -udfver102 -h "-lW11PRO_26H2_EEEP" "-bootdata:$boot" $Work $Out
if ($LASTEXITCODE) { throw "oscdimg exit=$LASTEXITCODE" }
"ISO gerada: $Out  $([math]::Round((Get-Item $Out).Length/1GB,2)) GB  $(Get-Date -Format HH:mm:ss)"
"SHA256: $((Get-FileHash $Out -Algorithm SHA256).Hash)"
