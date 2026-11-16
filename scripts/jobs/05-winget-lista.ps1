$w = (Get-Command winget -ErrorAction SilentlyContinue).Source
"winget: $w"
$o = cmd /c 'winget upgrade --include-unknown --accept-source-agreements --disable-interactivity 2>&1'
"exit=$LASTEXITCODE linhas=$($o.Count)"
$o | Where-Object { $_ -and $_.Trim().Length -gt 3 } | Select-Object -Last 80 | Out-String -Width 250
