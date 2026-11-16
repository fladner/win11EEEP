# Enfileira um script para rodar dentro da VM e aguarda a saida.
# Uso: Run-Guest.ps1 -Agent sys|user -Script '<codigo>'  |  -File caminho.ps1   [-TimeoutSec 600]
param(
    [ValidateSet('sys', 'user', 'par')][string]$Agent = 'sys',
    [string]$Script, [string]$File, [int]$TimeoutSec = 600,
    [string]$Root = 'C:\win11EEEP\build'
)
if ($File) { $Script = [IO.File]::ReadAllText($File) }
$id = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), $Agent
$dir = Join-Path $Root "queue\$Agent"; New-Item -ItemType Directory -Force $dir | Out-Null
[IO.File]::WriteAllText((Join-Path $dir "$id.ps1.tmp"), $Script, (New-Object Text.UTF8Encoding $false))
Rename-Item (Join-Path $dir "$id.ps1.tmp") "$id.ps1"
$res = Join-Path $Root "results\$id.txt"
$t0 = Get-Date
while (-not (Test-Path $res)) {
    if (((Get-Date) - $t0).TotalSeconds -gt $TimeoutSec) { "TIMEOUT aguardando $id (resultado chegara em $res)"; exit 3 }
    Start-Sleep -Seconds 2
}
Start-Sleep -Milliseconds 300
[IO.File]::ReadAllText($res)
