# Executa na VM EEEP-2025 (base: ISO de 22/02/2025, Windows 11 23H2), em sequencia, as etapas indicadas.
# Uso: Sequencia-2025.ps1 -Etapas 'sys:07','sys:08','user:30' ...   (agente:prefixo do job em scripts\jobs)
param([string[]]$Etapas, [int]$TimeoutSec = 18000)
$run = 'C:\win11EEEP\scripts\host\Run-Guest.ps1'
# com powershell -File o array chega como um texto so ("sys:07,sys:08")
$Etapas = @($Etapas | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
foreach ($e in $Etapas) {
    $agent, $pre = $e.Split(':')
    $f = Get-ChildItem "C:\win11EEEP\scripts\jobs\$pre-*.ps1" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $f) { $f = Get-Item $pre -ErrorAction SilentlyContinue }
    if (-not $f) { "######## arquivo ausente: $pre"; continue }
    "######## $($f.Name) [$agent] - inicio $(Get-Date -Format HH:mm:ss)"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $run -Agent $agent -File $f.FullName -TimeoutSec $TimeoutSec
    "######## $($f.Name) - fim $(Get-Date -Format HH:mm:ss)"
}
'sequencia concluida'
