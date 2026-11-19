# Diagnostico de boot (0xc0000017 no winload): grava em C:\diag-boot (lido depois pelo host a partir do VDI)
$o = 'C:\diag-boot'; New-Item -ItemType Directory -Force $o | Out-Null
& bcdedit.exe /enum all /v > "$o\bcd.txt" 2>&1
& bcdedit.exe /enum firmware /v > "$o\firmware.txt" 2>&1
# drivers de inicializacao (Start=0) e de sistema (Start=1): o winload carrega os de Start=0
$r = foreach ($s in Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Services) {
    $p = Get-ItemProperty $s.PSPath -ErrorAction SilentlyContinue
    if ($null -ne $p.Start -and $p.Start -le 1 -and $p.Type -le 2) {
        $img = [Environment]::ExpandEnvironmentVariables([string]$p.ImagePath) -replace '^\\SystemRoot', $env:WINDIR -replace '^System32', "$env:WINDIR\System32" -replace '^\\\?\?\\', ''
        $tam = if ($img -and (Test-Path -LiteralPath $img)) { (Get-Item -LiteralPath $img).Length } else { $null }
        [pscustomobject]@{ Start = $p.Start; Nome = $s.PSChildName; Grupo = $p.Group; Tamanho = $tam; Imagem = $img }
    }
}
$r | Sort-Object Start, Nome | Format-Table -AutoSize | Out-String -Width 300 | Set-Content "$o\drivers-boot.txt"
"Start=0: {0} drivers, {1:N1} MB" -f @($r | Where-Object Start -eq 0).Count, ((@($r | Where-Object Start -eq 0) | Measure-Object Tamanho -Sum).Sum / 1MB) | Add-Content "$o\drivers-boot.txt"
Get-ChildItem "$env:WINDIR\System32\config" -File | Select-Object Name, Length | Format-Table -AutoSize | Out-String | Set-Content "$o\hives.txt"
Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard -ErrorAction SilentlyContinue | Format-List * | Out-String | Set-Content "$o\deviceguard.txt"
Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard -Recurse -ErrorAction SilentlyContinue | ForEach-Object { "[$($_.Name)]"; Get-ItemProperty $_.PSPath | Format-List * | Out-String } | Add-Content "$o\deviceguard.txt"
Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue | Format-List * | Out-String | Add-Content "$o\deviceguard.txt"
Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing -ErrorAction SilentlyContinue | Format-List * | Out-String | Set-Content "$o\secureboot.txt"
Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot -ErrorAction SilentlyContinue | Format-List * | Out-String | Add-Content "$o\secureboot.txt"
Get-WindowsOptionalFeature -Online | Where-Object State -eq Enabled | Select-Object FeatureName | Out-String | Set-Content "$o\features.txt"
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' | Format-List * | Out-String | Set-Content "$o\memory.txt"
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control' | Format-List * | Out-String | Add-Content "$o\memory.txt"
# ACL do registro do Aluno depois da correcao
& reg.exe load HKU\EEEPCHK C:\Users\Aluno\NTUSER.DAT 2>&1 | Out-Null
"Aluno SID atual: $((Get-LocalUser Aluno).SID.Value)" | Set-Content "$o\aluno-acl.txt"
foreach ($k in 'HKEY_USERS\EEEPCHK', 'HKEY_USERS\EEEPCHK\Software', 'HKEY_USERS\EEEPCHK\Software\Microsoft\Windows\CurrentVersion', 'HKEY_USERS\EEEPCHK\Software\Policies') {
    $a = Get-Acl "Registry::$k" -ErrorAction SilentlyContinue; "$k`n  $($a.Sddl)" | Add-Content "$o\aluno-acl.txt"
}
Remove-Variable a; [gc]::Collect(); [gc]::WaitForPendingFinalizers(); Start-Sleep 1
& reg.exe unload HKU\EEEPCHK 2>&1 | Add-Content "$o\aluno-acl.txt"
'ok' | Set-Content "$o\fim.txt"
