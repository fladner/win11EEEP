# Executa na VM, em sequencia, as etapas de instalacao (cada uma so comeca quando a anterior termina).
$run = 'C:\win11EEEP\scripts\host\Run-Guest.ps1'
$steps = @(
    @{ n = 'Kit (instalacao direta)'; f = 'C:\win11EEEP\scripts\jobs\30-instalar-kit.ps1'; t = 18000 },
    @{ n = 'XAMPP 8.2 + servicos';    f = 'C:\win11EEEP\scripts\jobs\31-xampp-servicos.ps1'; t = 7200 },
    @{ n = 'PostgreSQL 18';           f = 'C:\win11EEEP\build\pg18.ps1'; t = 5400 },
    @{ n = 'Revit 2027';              f = 'C:\win11EEEP\scripts\jobs\40-revit2027.ps1'; t = 14400 }
)
foreach ($s in $steps) {
    "######## $($s.n) - inicio $(Get-Date -Format HH:mm:ss)"
    if (-not (Test-Path $s.f)) { "arquivo ausente: $($s.f)"; continue }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $run -Agent user -File $s.f -TimeoutSec $s.t
    "######## $($s.n) - fim $(Get-Date -Format HH:mm:ss)"
}
# o comando do PostgreSQL contem a senha: apagar as copias locais
Remove-Item C:\win11EEEP\build\pg18.ps1 -Force -ErrorAction SilentlyContinue
Get-ChildItem C:\win11EEEP\build\sent -File | Where-Object { (Select-String -LiteralPath $_.FullName -Pattern 'superpassword=' -Quiet) } | Remove-Item -Force
'sequencia concluida'
