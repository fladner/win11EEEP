foreach ($root in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') {
    foreach ($k in Get-ChildItem $root -ErrorAction SilentlyContinue) {
        if ($k.GetValue('DisplayName') -like 'DAEMON Tools*') {
            "chave: $($k.PSChildName)"; "Uninstall: $($k.GetValue('UninstallString'))"; "Quiet: $($k.GetValue('QuietUninstallString'))"
        }
    }
}
Get-ChildItem 'C:\Program Files\DAEMON Tools Lite' -Filter *.exe | Select-Object Name, Length
(Get-Service | Where-Object { $_.Name -match 'Disc|dtlite|DAEMON' -or $_.DisplayName -match 'Disc Soft|DAEMON' } | Select-Object Name, DisplayName, Status | Out-String).Trim()
(Get-CimInstance Win32_SystemDriver | Where-Object { $_.Name -match 'dtlite|dtsoft|dtscsi' -or $_.PathName -match 'dtlite|DAEMON|Disc' } | Select-Object Name, State, PathName | Out-String).Trim()
