Get-Content C:\ProgramData\EEEPBuild\wu.log | Select-Object -Last 8
'---'; Get-Date -Format HH:mm:ss
(Get-Process TiWorker, MoUsoCoreWorker, TrustedInstaller -ErrorAction SilentlyContinue | Select-Object Name, @{n='CPUs';e={[int]$_.CPU}} | Out-String).Trim()
'Download GB: ' + [math]::Round(((Get-ChildItem C:\Windows\SoftwareDistribution\Download -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB), 2)
$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'; "build $($cv.CurrentBuild).$($cv.UBR)"
'reinicio pendente: ' + (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
