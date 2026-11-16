$ErrorActionPreference = 'SilentlyContinue'
Get-Date -Format HH:mm:ss
"C: livre GB: $([math]::Round((Get-PSDrive C).Free/1GB,1))"
"pasta Revit 2027 GB: $([math]::Round(((Get-ChildItem 'C:\Program Files\Autodesk\Revit 2027' -Recurse -Force | Measure-Object Length -Sum).Sum/1GB),1))  Revit.exe: $(Test-Path 'C:\Program Files\Autodesk\Revit 2027\Revit.exe')"
$l = Get-ChildItem "C:\Users\Administrador\AppData\Local\Autodesk\ODIS\*.log", "$env:ProgramData\Autodesk\ODIS\*.log" | Sort-Object LastWriteTime | Select-Object -Last 1
if ($l) { "log: $($l.Name) $($l.LastWriteTime.ToString('HH:mm:ss'))"; Select-String -LiteralPath $l.FullName -Pattern 'Installing package|install package|Package.*(succeed|complete|fail)|progress' | Select-Object -Last 6 | ForEach-Object { $_.Line.Substring(0, [math]::Min(170, $_.Line.Length)) }; "pacotes concluidos: $(@(Select-String -LiteralPath $l.FullName -Pattern 'install.*(succeed|success|complete)').Count)" }
Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(Setup|Installer|msiexec|install_manager)\.exe$' } | ForEach-Object { "$($_.Name) inicio=$($_.CreationDate.ToString('HH:mm'))" }
