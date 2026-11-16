# Baixa do Catalogo do Microsoft Update o pacote de habilitacao do 26H2 (KB5121794, x64) e instala.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
"build atual: $($cv.CurrentBuild).$($cv.UBR) ($($cv.DisplayVersion))"
if ([int]$cv.CurrentBuild -ge 26300) { 'ja esta no 26H2'; return }
$kb = 'KB5121794'
$dir = 'C:\ProgramData\EEEPBuild\ekb'; New-Item -ItemType Directory -Force $dir | Out-Null
$search = Invoke-WebRequest -UseBasicParsing "https://www.catalog.update.microsoft.com/Search.aspx?q=$kb"
$rows = [regex]::Matches($search.Content, '(?s)<a[^>]+id=''([0-9a-f-]{36})_link''[^>]*>\s*(.*?)\s*</a>')
$pick = $null
foreach ($m in $rows) { $t = $m.Groups[2].Value.Trim(); "catalogo: $t"; if ($t -match 'x64' -and $t -notmatch 'arm64' -and -not $pick) { $pick = $m.Groups[1].Value } }
if (-not $pick) { throw 'pacote x64 nao encontrado no catalogo' }
$body = @{ updateIDs = "[{`"size`":0,`"languages`":`"`",`"uidInfo`":`"$pick`",`"updateID`":`"$pick`"}]" }
$dl = Invoke-WebRequest -UseBasicParsing -Method Post -Uri 'https://www.catalog.update.microsoft.com/DownloadDialog.aspx' -Body $body
$urls = [regex]::Matches($dl.Content, "downloadInformation\[0\]\.files\[\d+\]\.url = '([^']+)'") | ForEach-Object { $_.Groups[1].Value }
$url = $urls | Where-Object { $_ -match '\.msu$' } | Select-Object -First 1
if (-not $url) { throw "URL .msu nao encontrada: $($urls -join ', ')" }
"url: $url"
if ($url -notmatch '^https?://[^/]*(windowsupdate\.com|microsoft\.com)/') { throw 'URL fora dos dominios da Microsoft' }
$file = Join-Path $dir ([IO.Path]::GetFileName(($url -split '\?')[0]))
(New-Object Net.WebClient).DownloadFile($url, $file)
$sig = Get-AuthenticodeSignature $file
"arquivo: $file  $([math]::Round((Get-Item $file).Length/1KB)) KB  assinatura: $($sig.Status) / $($sig.SignerCertificate.Subject)"
if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') { throw 'assinatura invalida' }
$out = & dism.exe /Online /Add-Package "/PackagePath:$file" /NoRestart /English 2>&1
$out | Select-Object -Last 8
"dism exit=$LASTEXITCODE"
