# Limpeza final antes da generalizacao: temporarios, instaladores, caches e componentes antigos do Windows.
$ErrorActionPreference = 'SilentlyContinue'
function GB($p) { [math]::Round(((Get-ChildItem -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB), 2) }
$before = (Get-PSDrive C).Free
"C: livre antes: $([math]::Round($before/1GB,1)) GB"
Get-Process OneDrive, Postman, Code, msedge, chrome, firefox -ErrorAction SilentlyContinue | Stop-Process -Force
Stop-Service wuauserv, bits, UsoSvc, DoSvc -Force

$targets = @('C:\Windows\Temp\*', 'C:\Windows\SoftwareDistribution\Download\*', 'C:\Windows\Prefetch\*', 'C:\ProgramData\Microsoft\Windows\WER\*',
    'C:\Windows\Logs\CBS\*.cab', 'C:\Windows\Downloaded Program Files\*', 'C:\$WINDOWS.~BT', 'C:\$WINDOWS.~WS', 'C:\Windows.old', 'C:\$GetCurrent', 'C:\MSOCache',
    # LabSetup: sai so o que e instalador; UserConfig\Configure-LabUser.ps1 roda no logon de cada usuario (chave Run)
    'C:\Autodesk', 'C:\ProgramData\LabSetup\Packages', 'C:\ProgramData\LabSetup\Downloads', 'C:\ProgramData\LabSetup\UserConfig\Packages', 'C:\DumpStack.log*', 'C:\Windows\Panther\*.etl')
foreach ($u in Get-ChildItem C:\Users -Directory -Force | Where-Object { $_.Name -notin 'Public', 'All Users', 'Default User' }) {
    $targets += "$($u.FullName)\AppData\Local\Temp\*","$($u.FullName)\AppData\Local\Microsoft\Windows\INetCache\*",
        "$($u.FullName)\AppData\Local\Microsoft\Windows\WebCache\*", "$($u.FullName)\AppData\Local\CrashDumps\*", "$($u.FullName)\AppData\Local\Microsoft\Windows\Explorer\thumbcache*",
        "$($u.FullName)\AppData\Local\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir\*", "$($u.FullName)\AppData\Local\pip\cache", "$($u.FullName)\AppData\Local\Postman\packages\*.nupkg"
}
foreach ($t in $targets) {
    $sz = 0; Get-Item $t -Force | ForEach-Object { $sz += if ($_.PSIsContainer) { (Get-ChildItem -LiteralPath $_.FullName -Recurse -Force | Measure-Object Length -Sum).Sum } else { $_.Length } }
    if ($sz -gt 50MB) { "  {0,7:N2} GB  {1}" -f ($sz / 1GB), $t }
    Remove-Item $t -Recurse -Force
}
Clear-RecycleBin -Force
& powercfg.exe /h off
"--- pastas Downloads dos perfis (NAO apagadas; conferir):"
Get-ChildItem 'C:\Users\*\Downloads' -Directory | ForEach-Object { "  {0,6:N2} GB  {1}  ({2} itens)" -f (GB $_.FullName), $_.FullName, @(Get-ChildItem $_.FullName -Force).Count }
"--- instaladores avulsos restantes (maiores que 100 MB) fora das pastas dos programas:"
Get-ChildItem 'C:\', 'C:\Users\*\Desktop', 'C:\Users\*\Documents', 'C:\Users\Public' -File -Include *.exe, *.msi, *.iso, *.zip, *.rar, *.7z -Recurse -Depth 1 | Where-Object { $_.Length -gt 100MB } | ForEach-Object { "  {0,6:N0} MB  {1}" -f ($_.Length / 1MB), $_.FullName }
"--- componentes antigos do Windows (pode demorar):"
& dism.exe /Online /Cleanup-Image /StartComponentCleanup /English | Select-Object -Last 3
Start-Service wuauserv, bits
foreach ($l in (& wevtutil.exe el)) { & wevtutil.exe cl $l 2>$null }
"C: livre depois: $([math]::Round((Get-PSDrive C).Free/1GB,1)) GB  (liberado: $([math]::Round(((Get-PSDrive C).Free-$before)/1GB,1)) GB)  usado: $([math]::Round((Get-PSDrive C).Used/1GB,1)) GB"
