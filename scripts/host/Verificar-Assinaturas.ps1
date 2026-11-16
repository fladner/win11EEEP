# Extrai um pacote para uma pasta isolada e confere a assinatura Authenticode de todos os
# executaveis, DLLs, MSIs e scripts. Nao executa nada do pacote.
param([Parameter(Mandatory)][string]$Archive, [Parameter(Mandatory)][string]$Dest)
$z = 'C:\Program Files\7-Zip\7z.exe'
if (-not (Test-Path $Dest)) {
    New-Item -ItemType Directory -Force $Dest | Out-Null
    & $z x $Archive "-o$Dest" -y -bso0 -bsp0
    "extracao exit=$LASTEXITCODE"
}
$all = Get-ChildItem $Dest -Recurse -File
"arquivos: $($all.Count)  tamanho GB: $([math]::Round(($all | Measure-Object Length -Sum).Sum/1GB,2))"
"por extensao: " + (($all | Group-Object Extension | Sort-Object Count -Descending | Select-Object -First 15 | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' ')
$check = $all | Where-Object { $_.Extension -in '.exe', '.dll', '.msi', '.msp', '.msu', '.cab', '.ps1', '.vbs', '.js', '.sys', '.cat' }
$res = foreach ($f in $check) {
    $s = Get-AuthenticodeSignature -LiteralPath $f.FullName
    [pscustomobject]@{ File = $f.FullName.Substring($Dest.Length + 1); Status = $s.Status; Signer = if ($s.SignerCertificate) { ($s.SignerCertificate.Subject -replace '^.*?O=("?)([^,"]+)\1.*$', '$2') } else { '' } }
}
"verificados: $($res.Count)"
'--- por status/assinante:'
$res | Group-Object Status, Signer | Sort-Object Count -Descending | ForEach-Object { '{0,5}  {1}' -f $_.Count, $_.Name }
'--- nao validos (ate 60):'
$res | Where-Object { $_.Status -ne 'Valid' } | Select-Object -First 60 | ForEach-Object { "$($_.Status) | $($_.File)" }
'--- arquivos soltos com cara de script/atalho na raiz ou incomuns:'
$all | Where-Object { $_.Extension -in '.bat', '.cmd', '.reg', '.lnk', '.url', '.scr', '.com', '.pif', '.hta' } | Select-Object -First 30 | ForEach-Object { $_.FullName.Substring($Dest.Length + 1) }
$setup = Get-ChildItem $Dest -Recurse -Filter Setup.exe | Select-Object -First 1
if ($setup) { "Setup.exe: versao $($setup.VersionInfo.FileVersion) / $($setup.VersionInfo.ProductName)"; $sg = Get-AuthenticodeSignature $setup.FullName; "  assinatura: $($sg.Status) / $($sg.SignerCertificate.Subject) / validade ate $($sg.SignerCertificate.NotAfter.ToString('yyyy-MM-dd')) / carimbo de tempo: $([bool]$sg.TimeStamperCertificate)" }
