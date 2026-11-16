$ErrorActionPreference = 'SilentlyContinue'
"data da VM: $(Get-Date -Format 's')"
$f = Get-Item 'C:\Program Files\Autodesk\AutoCAD 2027\acad.exe'
"acad.exe: versao $($f.VersionInfo.FileVersion) | produto $($f.VersionInfo.ProductName) $($f.VersionInfo.ProductVersion) | data do arquivo $($f.LastWriteTime.ToString('yyyy-MM-dd'))"
"comentario: $($f.VersionInfo.Comments) | descricao: $($f.VersionInfo.FileDescription)"
foreach ($root in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') {
    Get-ChildItem $root | ForEach-Object { $n = $_.GetValue('DisplayName'); if ($n -like '*AutoCAD 2027*') { "registro: $n | $($_.GetValue('DisplayVersion')) | instalado em $($_.GetValue('InstallDate'))" } }
}
Get-ChildItem 'C:\Program Files\Autodesk\AutoCAD 2027' -Filter '*.txt' | Select-Object -First 5 Name
Select-String -Path 'C:\Program Files\Autodesk\AutoCAD 2027\*.xml', 'C:\ProgramData\Autodesk\ODIS\metadata\*\*.xml' -Pattern 'beta|pre-?release|preview' -List | Select-Object -First 6 | ForEach-Object { "$($_.Path): $($_.Line.Trim().Substring(0,[math]::Min(140,$_.Line.Trim().Length)))" }
