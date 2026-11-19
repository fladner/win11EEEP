# Servidor de arquivos SOMENTE LEITURA para a VM (escuta so no loopback; a VM chega pelo NAT em 10.0.2.2).
#   GET /<nome>  -> conteudo de <Pasta>\<nome> (so arquivos diretamente na pasta; sem subpastas, sem "..")
param([int]$Port = 8766, [string]$Pasta = 'C:\win11EEEP\build\adobe')
$ErrorActionPreference = 'Stop'
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
$listener.Start()
"servindo $Pasta em 127.0.0.1:$Port"
$enc = [Text.Encoding]::ASCII
while ($true) {
    $c = $listener.AcceptTcpClient()
    try {
        $s = $c.GetStream(); $buf = New-Object byte[] 8192; $req = ''
        while ($req.IndexOf("`r`n`r`n") -lt 0) { $n = $s.Read($buf, 0, $buf.Length); if ($n -le 0) { break }; $req += $enc.GetString($buf, 0, $n) }
        $nome = [Uri]::UnescapeDataString(($req.Split("`n")[0].Split(' ')[1]).TrimStart('/'))
        $f = Join-Path $Pasta $nome
        if ($nome -match '[\\/]|\.\.' -or -not (Test-Path -LiteralPath $f -PathType Leaf)) {
            $h = $enc.GetBytes("HTTP/1.1 404 Not Found`r`nContent-Length: 0`r`nConnection: close`r`n`r`n"); $s.Write($h, 0, $h.Length)
        } else {
            $fs = [IO.File]::OpenRead($f)
            $h = $enc.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: application/octet-stream`r`nContent-Length: $($fs.Length)`r`nConnection: close`r`n`r`n"); $s.Write($h, 0, $h.Length)
            $fs.CopyTo($s, 1MB); $fs.Close()
            "{0:HH:mm:ss} enviado {1}" -f (Get-Date), $nome
        }
    } catch { "erro: $($_.Exception.Message)" } finally { $c.Close() }
}
