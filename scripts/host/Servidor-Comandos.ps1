# Fila de comandos host -> VM (somente loopback; a VM alcanca o host pelo NAT em 10.0.2.2).
#   GET  /next?agent=<nome>   -> "id`n<script>" (200) ou 204 se a fila estiver vazia
#   POST /result?id=<id>      -> grava a saida em build\results\<id>.txt
# Para enfileirar: gravar build\queue\<agente>\<id>.ps1
param([int]$Port = 8765, [string]$Root = 'C:\win11EEEP\build')
$ErrorActionPreference = 'Stop'
$queue = Join-Path $Root 'queue'; $results = Join-Path $Root 'results'; $sent = Join-Path $Root 'sent'
foreach ($d in $queue, $results, $sent) { New-Item -ItemType Directory -Force $d | Out-Null }
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
$listener.Start()
"ouvindo em 127.0.0.1:$Port"
$enc = [Text.Encoding]::UTF8
function Send-Response($stream, [int]$code, [byte[]]$body) {
    $head = "HTTP/1.1 $code OK`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
    $h = $enc.GetBytes($head); $stream.Write($h, 0, $h.Length)
    if ($body.Length) { $stream.Write($body, 0, $body.Length) }
}
while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
        $client.ReceiveTimeout = 30000
        $s = $client.GetStream()
        $buf = New-Object byte[] 65536; $ms = New-Object IO.MemoryStream
        $headerEnd = -1
        while ($headerEnd -lt 0) {
            $n = $s.Read($buf, 0, $buf.Length); if ($n -le 0) { break }
            $ms.Write($buf, 0, $n)
            $txt = [Text.Encoding]::ASCII.GetString($ms.GetBuffer(), 0, [int]$ms.Length)
            $headerEnd = $txt.IndexOf("`r`n`r`n")
        }
        if ($headerEnd -lt 0) { continue }
        $header = $txt.Substring(0, $headerEnd)
        $first = $header.Split("`n")[0].Trim()
        $method, $url = $first.Split(' ')[0, 1]
        $len = 0; if ($header -match '(?im)^Content-Length:\s*(\d+)') { $len = [int]$Matches[1] }
        $bodyStart = $headerEnd + 4
        while (($ms.Length - $bodyStart) -lt $len) {
            $n = $s.Read($buf, 0, $buf.Length); if ($n -le 0) { break }
            $ms.Write($buf, 0, $n)
        }
        $body = New-Object byte[] $len
        if ($len) { [Array]::Copy($ms.GetBuffer(), $bodyStart, $body, 0, $len) }
        $q = @{}
        if ($url -match '\?(.*)$') { foreach ($p in $Matches[1].Split('&')) { $kv = $p.Split('=', 2); if ($kv.Count -eq 2) { $q[$kv[0]] = [Uri]::UnescapeDataString($kv[1]) } } }
        if ($method -eq 'GET' -and $url -like '/next*') {
            $agent = ($q['agent'] -replace '[^A-Za-z0-9_-]', '')
            $dir = Join-Path $queue $agent
            Set-Content -LiteralPath (Join-Path $Root "alive-$agent.txt") -Value (Get-Date -Format s)
            $job = $null
            if (Test-Path $dir) { $job = Get-ChildItem $dir -Filter *.ps1 | Sort-Object Name | Select-Object -First 1 }
            if ($job) {
                $id = $job.BaseName
                $payload = $enc.GetBytes($id + "`n" + [IO.File]::ReadAllText($job.FullName))
                Move-Item $job.FullName (Join-Path $sent $job.Name) -Force
                Send-Response $s 200 $payload
            } else { Send-Response $s 204 @() }
        } elseif ($method -eq 'POST' -and $url -like '/result*') {
            $id = ($q['id'] -replace '[^A-Za-z0-9_.-]', '')
            [IO.File]::WriteAllBytes((Join-Path $results "$id.txt"), $body)
            Send-Response $s 200 $enc.GetBytes('ok')
        } else { Send-Response $s 404 $enc.GetBytes('?') }
    } catch { } finally { $client.Close() }
}
