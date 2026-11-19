foreach ($f in Get-ChildItem C:\diag-boot -File) {
    try { Invoke-WebRequest -Uri ("http://10.0.2.2:8765/result?id=diag-" + $f.BaseName) -Method Post -InFile $f.FullName -UseBasicParsing | Out-Null; "enviado $($f.Name)" } catch { "falhou $($f.Name): $_" }
}
