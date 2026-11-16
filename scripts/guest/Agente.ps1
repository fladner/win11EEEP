# Agente temporario de build (roda DENTRO da VM). Busca scripts na fila do host e devolve a saida.
# Cada tarefa roda em um processo proprio, entao varias podem rodar em paralelo.
# E removido da imagem antes da captura (ver Remover-Agente.ps1).
param([string]$Name = 'user', [string]$HostUrl = 'http://10.0.2.2:8765', [string]$RunJob)
$ErrorActionPreference = 'Continue'
$work = 'C:\ProgramData\EEEPBuild'; New-Item -ItemType Directory -Force $work | Out-Null
$wc = New-Object Net.WebClient; $wc.Encoding = [Text.Encoding]::UTF8

if ($RunJob) {
    $f = Join-Path $work "$RunJob.ps1"
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $f 2>&1 | Out-String
    $out += "`n[exit=$LASTEXITCODE]"
    [IO.File]::WriteAllText((Join-Path $work "$RunJob.out.txt"), $out)
    for ($t = 0; $t -lt 40; $t++) { try { [void]$wc.UploadString("$HostUrl/result?id=$RunJob", $out); break } catch { Start-Sleep 5 } }
    exit
}

while ($true) {
    try {
        $r = $wc.DownloadString("$HostUrl/next?agent=$Name")
        if ($r) {
            $i = $r.IndexOf("`n"); $id = $r.Substring(0, $i).Trim(); $script = $r.Substring($i + 1)
            [IO.File]::WriteAllText((Join-Path $work "$id.ps1"), $script, (New-Object Text.UTF8Encoding $true))
            Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-RunJob', $id, '-HostUrl', $HostUrl
            continue
        }
    } catch { }
    Start-Sleep -Seconds 3
}
