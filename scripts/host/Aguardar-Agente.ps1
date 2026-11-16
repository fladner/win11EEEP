# Aguarda um agente da VM dar sinal de vida recente (arquivo build\alive-<nome>.txt).
param([string]$Agent = 'sys', [int]$MaxMin = 30)
$t0 = Get-Date
while (((Get-Date) - $t0).TotalMinutes -lt $MaxMin) {
    $f = Get-Item "C:\win11EEEP\build\alive-$Agent.txt" -ErrorAction SilentlyContinue
    if ($f -and ((Get-Date) - $f.LastWriteTime).TotalSeconds -lt 15) { "agente $Agent ativo ($([int]((Get-Date)-$t0).TotalSeconds)s)"; exit 0 }
    Start-Sleep 3
}
"agente $Agent nao conectou em $MaxMin min"; exit 1
