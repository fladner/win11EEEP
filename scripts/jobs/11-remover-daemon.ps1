$ErrorActionPreference = 'Continue'
$dir = 'C:\Program Files\DAEMON Tools Lite'
Get-Process DTLite, DTAgent, DTHelper, DTShellHlp, DiscSoftBusServiceLite -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$p = Start-Process "$dir\uninst.exe" -ArgumentList '-uninstall', '-silent' -PassThru
$ok = $p.WaitForExit(240000)
"uninst terminou=$ok exit=$(if ($ok) { $p.ExitCode })"
Start-Sleep 10
"pasta existe: $(Test-Path "$dir\DTLite.exe")"
"processos uninst: " + ((Get-Process uninst* -ErrorAction SilentlyContinue | ForEach-Object { "$($_.ProcessName):$($_.MainWindowTitle)" }) -join '; ')
(Get-CimInstance Win32_SystemDriver | Where-Object { $_.Name -match 'dtlite' } | Select-Object Name, State | Out-String).Trim()
