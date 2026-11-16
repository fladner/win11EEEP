$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\kit.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
Get-Volume | Where-Object DriveType -eq 'CD-ROM' | ForEach-Object { "unidade $($_.DriveLetter): rotulo=$($_.FileSystemLabel)" }
$setup = Get-PSDrive -PSProvider FileSystem | ForEach-Object { Join-Path $_.Root 'acad2027\Setup.exe' } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $setup) {
    'acad2027 nao visivel; raiz das unidades de DVD:'
    Get-Volume | Where-Object DriveType -eq 'CD-ROM' | ForEach-Object { Get-ChildItem "$($_.DriveLetter):\" -ErrorAction SilentlyContinue | ForEach-Object Name }
    return
}
L "instalando AutoCAD 2027 oficial a partir de $setup"
$p = Start-Process $setup -ArgumentList '-q' -PassThru
if ($p.WaitForExit(120 * 60000)) { L "AutoCAD 2027 Setup exit=$($p.ExitCode)" } else { L 'AutoCAD 2027 TIMEOUT' }
for ($i = 0; $i -lt 90 -and (Get-Process Installer, install_manager -ErrorAction SilentlyContinue); $i++) { Start-Sleep 10 }
$f = Get-Item 'C:\Program Files\Autodesk\AutoCAD 2027\acad.exe' -ErrorAction SilentlyContinue
L "acad.exe: $($f.VersionInfo.FileVersion)"
"C: livre GB: $([math]::Round((Get-PSDrive C).Free/1GB,1))"
