$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
try {
    $s = Invoke-WebRequest -UseBasicParsing 'https://www.catalog.update.microsoft.com/Search.aspx?q=KB5121794'
    "catalogo: status=$($s.StatusCode) tamanho=$($s.Content.Length)"
    [regex]::Matches($s.Content, "id=[`"']([0-9a-f-]{36})_link[`"'][^>]*>\s*([^<]+)") | ForEach-Object { "  $($_.Groups[1].Value) | $($_.Groups[2].Value.Trim())" }
    if ($s.Content -match 'no results|não encontrou|We did not find') { '  (sem resultados no catalogo)' }
} catch { "catalogo erro: $($_.Exception.Message)" }
'--- Windows Update (software, nao instalado):'
$sess = New-Object -ComObject Microsoft.Update.Session
$r = $sess.CreateUpdateSearcher().Search("IsInstalled=0 and Type='Software'")
foreach ($u in $r.Updates) { '{0} | {1:N0} MB | {2}' -f $u.Title, ($u.MaxDownloadSize / 1MB), (($u.Categories | ForEach-Object Name) -join ',') }
"total: $($r.Updates.Count)"
'--- pacotes de habilitacao presentes no componente store:'
dism /online /get-packages /english | Select-String 'KB5121794|EnablementPackage|FeaturePack.*26H2|Package_for_KB51' | Select-Object -First 10
