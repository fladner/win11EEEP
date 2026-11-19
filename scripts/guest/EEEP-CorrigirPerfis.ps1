# Executado como SYSTEM no fim da instalacao (SetupComplete.cmd), antes do primeiro logon.
# O sysprep /generalize da um SID novo as contas locais (Aluno, CREDE...) e corrige as permissoes dos ARQUIVOS,
# mas NAO as permissoes de dentro do registro pessoal de cada perfil (NTUSER.DAT e UsrClass.dat), que continuam
# liberadas so para o SID antigo da maquina de montagem. Resultado: no logon do Aluno aparece
# "Falha na entrada do servico Cliente da Politica de Grupo. Acesso negado."
# Aqui cada ACE do SID antigo (mesmo RID, outro dominio de maquina) ganha a ACE equivalente para o SID novo.
param([string]$Log = "$env:WINDIR\Setup\Scripts\EEEP-CorrigirPerfis.log")
$ErrorActionPreference = 'Continue'
function L($m) { Add-Content $Log ("{0} {1}" -f (Get-Date -Format 's'), $m) }

$adm = Get-LocalUser | Where-Object { $_.SID.Value -match '-500$' } | Select-Object -First 1
$dominio = $adm.SID.AccountDomainSid.Value
L "inicio; dominio da maquina: $dominio"

$Rights = [Security.AccessControl.RegistryRights]
$sidRegex = '^S-1-5-21-\d+-\d+-\d+-(\d+)$'
$script:n = 0; $script:alteradas = 0

function Corrigir-Chave([Microsoft.Win32.RegistryKey]$base, [string]$sub, [string]$novo, [string]$rid) {
    try {
        $k = $base.OpenSubKey($sub, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
            ($Rights::ReadKey -bor $Rights::ChangePermissions))
    } catch { return }
    if (-not $k) { return }
    $script:n++
    try {
        $acl = $k.GetAccessControl()
        $mudou = $false
        foreach ($r in @($acl.GetAccessRules($true, $false, [Security.Principal.SecurityIdentifier]))) {
            $s = $r.IdentityReference.Value
            if ($s -match $sidRegex -and $Matches[1] -eq $rid -and $s -ne $novo -and -not $s.StartsWith("$dominio-")) {
                $acl.AddAccessRule((New-Object Security.AccessControl.RegistryAccessRule(
                    (New-Object Security.Principal.SecurityIdentifier $novo), $r.RegistryRights, $r.InheritanceFlags, $r.PropagationFlags, $r.AccessControlType)))
                [void]$acl.RemoveAccessRuleSpecific($r)
                $mudou = $true
            }
        }
        $dono = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
        if ($dono -match $sidRegex -and $Matches[1] -eq $rid -and -not $dono.StartsWith("$dominio-")) {
            $acl.SetOwner((New-Object Security.Principal.SecurityIdentifier $novo)); $mudou = $true
        }
        if ($mudou) { $k.SetAccessControl($acl); $script:alteradas++ }
    } catch { }
    try { $nomes = $k.GetSubKeyNames() } catch { $nomes = @() }
    $k.Close()
    foreach ($s in $nomes) { Corrigir-Chave $base ($(if ($sub) { "$sub\$s" } else { $s })) $novo $rid }
}

$pl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
foreach ($p in Get-ChildItem $pl) {
    $sid = $p.PSChildName
    if (-not $sid.StartsWith("$dominio-") -or $sid -notmatch $sidRegex) { continue }
    $rid = $Matches[1]
    $dir = [Environment]::ExpandEnvironmentVariables((Get-ItemProperty $p.PSPath).ProfileImagePath)
    foreach ($h in @("$dir\NTUSER.DAT", "$dir\AppData\Local\Microsoft\Windows\UsrClass.dat")) {
        if (-not (Test-Path -LiteralPath $h)) { continue }
        if (Test-Path "Registry::HKEY_USERS\$sid") { L "$h em uso (perfil carregado): ignorado"; continue }
        $tmp = 'EEEP_PERFIL'
        & reg.exe load "HKU\$tmp" $h 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { L "$h nao carregou"; continue }
        $script:n = 0; $script:alteradas = 0
        $raiz = [Microsoft.Win32.Registry]::Users
        Corrigir-Chave $raiz $tmp $sid $rid
        [gc]::Collect(); [gc]::WaitForPendingFinalizers()
        Start-Sleep -Milliseconds 500
        & reg.exe unload "HKU\$tmp" 2>&1 | Out-Null
        L "$h -> $sid : $($script:alteradas) de $($script:n) chaves corrigidas (unload exit $LASTEXITCODE)"
    }
}
L 'fim'
