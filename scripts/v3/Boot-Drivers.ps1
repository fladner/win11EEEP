# Fotografia dos drivers de inicializacao (Start=0, kernel/FS) e do tamanho do hive SYSTEM.
# Grava C:\ProgramData\EEEPBuild\boot-<Etapa>.txt e mostra o que mudou em relacao a etapa anterior.
param([string]$Etapa = 'agora')
$dir = 'C:\ProgramData\EEEPBuild'; New-Item -ItemType Directory -Force $dir | Out-Null
$lista = foreach ($s in Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Services) {
    $p = Get-ItemProperty $s.PSPath -ErrorAction SilentlyContinue
    if ($null -ne $p.Start -and $p.Start -eq 0 -and $p.Type -le 2) { "{0}|{1}" -f $s.PSChildName, $p.ImagePath }
}
$lista = @($lista | Sort-Object)
$sys = (Get-Item C:\Windows\System32\config\SYSTEM).Length
$out = Join-Path $dir "boot-$Etapa.txt"
@("SYSTEM=$sys") + $lista | Set-Content $out -Encoding UTF8
"etapa {0}: {1} drivers de boot, SYSTEM {2:N1} MB" -f $Etapa, $lista.Count, ($sys / 1MB)
$ant = Get-ChildItem $dir -Filter 'boot-*.txt' | Where-Object FullName -ne $out | Sort-Object LastWriteTime | Select-Object -Last 1
if ($ant) {
    $a = @(Get-Content $ant.FullName | Select-Object -Skip 1)
    $novos = $lista | Where-Object { $_ -notin $a }; $sairam = $a | Where-Object { $_ -notin $lista }
    "comparado com $($ant.BaseName): novos=$(@($novos).Count) removidos=$(@($sairam).Count)"
    $novos | ForEach-Object { "  + $_" }; $sairam | ForEach-Object { "  - $_" }
}
