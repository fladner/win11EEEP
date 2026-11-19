# Remove do catalogo Winsock o provedor de nomes (NSP) do NI mDNS Responder (nimdnsNSP.dll, vem com o Multisim).
# Motivo: no 26H2 instalado do zero a protecao da LSA (RunAsPPL) vem ligada; o LSASS se recusa a carregar essa DLL
# e o Windows mostra "Este modulo esta impedido de ser carregado na Autoridade de Seguranca Local" a cada logon.
# Sem o NSP perde-se apenas a descoberta automatica de equipamentos NI pela rede (o Multisim nao usa).
# Rodar como administrador (ou SYSTEM). A protecao da LSA continua ligada. Reiniciar depois.
$ErrorActionPreference = 'Continue'
Add-Type -Namespace EEEP -Name Ws2 -MemberDefinition @'
[DllImport("ws2_32.dll")] public static extern int WSCUnInstallNameSpace(ref System.Guid id);
[DllImport("ws2_32.dll")] public static extern int WSCUnInstallNameSpace32(ref System.Guid id);
[DllImport("ws2_32.dll")] public static extern int WSAGetLastError();
'@ -ErrorAction SilentlyContinue
$base = 'HKLM:\SYSTEM\CurrentControlSet\Services\WinSock2\Parameters\NameSpace_Catalog5'
$achou = 0
foreach ($cat in 'Catalog_Entries64', 'Catalog_Entries') {
    foreach ($e in Get-ChildItem "$base\$cat" -ErrorAction SilentlyContinue) {
        $p = Get-ItemProperty $e.PSPath
        if ([string]$p.LibraryPath -notmatch 'nimdnsNSP') { continue }
        $achou++
        $g = [guid]::new([byte[]]$p.ProviderId)
        $r = if ($cat -eq 'Catalog_Entries64') { [EEEP.Ws2]::WSCUnInstallNameSpace([ref]$g) } else { [EEEP.Ws2]::WSCUnInstallNameSpace32([ref]$g) }
        $err = if ($r -ne 0) { " erro=$([EEEP.Ws2]::WSAGetLastError())" } else { '' }
        "$cat : $($p.DisplayString) $g -> resultado $r$err"
    }
}
if (-not $achou) { 'nimdnsNSP nao esta no catalogo Winsock (nada a fazer)' }
'restantes com nimdnsNSP: ' + @(Get-ChildItem "$base\Catalog_Entries64", "$base\Catalog_Entries" -ErrorAction SilentlyContinue | Where-Object { [string](Get-ItemProperty $_.PSPath).LibraryPath -match 'nimdnsNSP' }).Count
