$ErrorActionPreference = 'SilentlyContinue'
$all = foreach ($root in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') {
    foreach ($k in Get-ChildItem $root) {
        $n = $k.GetValue('DisplayName'); if (-not $n -or $k.GetValue('SystemComponent') -eq 1 -or $k.GetValue('ParentKeyName')) { continue }
        [pscustomobject]@{ Name = $n; Ver = $k.GetValue('DisplayVersion'); Loc = $k.GetValue('InstallLocation'); Un = $k.GetValue('UninstallString'); Key = $k.PSChildName
            Norm = (($n -replace '\(.*?\)', '' -replace '[0-9][0-9A-Za-z._-]*', '' -replace '\b(x64|x86|64-bit|32-bit|IDE|version)\b', '' -replace '\s+', ' ').Trim().ToLower()) }
    }
}
'--- grupos com mais de uma entrada:'
$all | Group-Object Norm | Where-Object { $_.Count -gt 1 -and $_.Name -notmatch 'microsoft visual c\+\+|microsoft (asp|windows desktop|\.net)|mysql|autodesk|aplicativos da|adobe|sinutrain|autocad open' } | ForEach-Object {
    "[$($_.Name)]"; $_.Group | ForEach-Object { "   $($_.Name) | $($_.Ver) | $($_.Loc) | $($_.Un) | $($_.Key)" } }
'--- Arduino / LibreCAD / NetBeans / Java / Python / Packet Tracer / XAMPP:'
$all | Where-Object { $_.Name -match 'Arduino|LibreCAD|NetBeans|Java|JDK|Python|Packet Tracer|XAMPP|Inkscape|GIMP|FreeCAD|VirtualBox|Wireshark|Npcap|Postgre' } | Sort-Object Name | ForEach-Object { "   $($_.Name) | $($_.Ver) | $($_.Loc) | $($_.Un)" }
'--- pastas:'
Get-ChildItem 'C:\Program Files\arduino-ide', 'C:\Program Files\Arduino IDE', 'C:\Program Files\NetBeans*', 'C:\Program Files\LibreCAD', 'C:\Program Files (x86)\LibreCAD', 'C:\Program Files\Cisco Packet Tracer*' -Filter *.exe | Select-Object FullName, @{n='Ver';e={$_.VersionInfo.ProductVersion}} | Format-Table -AutoSize | Out-String -Width 200
'--- atalhos (area de trabalho publica e menu iniciar) desses programas:'
Get-ChildItem 'C:\Users\Public\Desktop', 'C:\Users\*\Desktop', 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs' -Recurse -Include *Arduino*, *LibreCAD*, *NetBeans*, *Packet*, *GIMP*, *FreeCAD* | ForEach-Object { $t = (New-Object -ComObject WScript.Shell).CreateShortcut($_.FullName).TargetPath; "   $($_.FullName) -> $t" }
"XAMPP: " + (Select-String -Path C:\xampp\properties.ini -Pattern 'base_stack_version').Line
