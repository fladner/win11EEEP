# Executado UMA vez em cada computador instalado com a ISO EEEP (passo "specialize" do Windows Setup e,
# como reserva, tarefa agendada na inicializacao). Garante identidade propria por maquina.
$marker = 'HKLM:\SOFTWARE\EEEP'
if ((Get-ItemProperty $marker -Name PrimeiroBoot -ErrorAction SilentlyContinue).PrimeiroBoot) { exit 0 }
$log = 'C:\Windows\Setup\Scripts\EEEP-PrimeiroBoot.log'
function L($m) { Add-Content $log ("{0} {1}" -f (Get-Date -Format 's'), $m) }
L "inicio em $env:COMPUTERNAME"

# 1. Identificador de maquina novo (usado por RustDesk e outros programas para gerar o ID)
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid -Value ([guid]::NewGuid().ToString())
L 'MachineGuid regenerado'

# Para servicos sem esperar: no passo specialize o Stop-Service do AnyDesk ficava esperando para sempre.
function Parar($svc, $proc) {
    & sc.exe stop $svc 2>&1 | Out-Null
    Start-Sleep -Seconds 3
    & taskkill.exe /f /im "$proc.exe" 2>&1 | Out-Null
    Start-Sleep -Seconds 1
}

# 2. AnyDesk: sem ID/chaves herdados -> o servico pede um ID novo ao iniciar
Parar AnyDesk AnyDesk
Remove-Item 'C:\ProgramData\AnyDesk\service.conf' -Force -ErrorAction SilentlyContinue

# 3. RustDesk: remove ID e par de chaves; preserva senha permanente e servidor (RustDesk2.toml)
Parar RustDesk rustdesk
$toml = 'C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml'
if (Test-Path $toml) {
    $out = New-Object Collections.Generic.List[string]; $skip = $false
    foreach ($line in [IO.File]::ReadAllLines($toml)) {
        if ($skip) { if ($line -match '\]\s*$' -and $line -notmatch '^\s*\[\w') { $skip = $false }; continue }
        if ($line -match '^\s*(id|enc_id|key_confirmed)\s*=') { continue }
        if ($line -match '^\s*key_pair\s*=') { if ($line -notmatch '\]\s*\]\s*$') { $skip = $true }; continue }
        if ($line -match '^\s*\[keys_confirmed\]') { $skip = $false; $inKeys = $true; continue }
        if ($inKeys) { if ($line -match '^\s*\[') { $inKeys = $false } else { continue } }
        $out.Add($line)
    }
    [IO.File]::WriteAllLines($toml, $out, (New-Object Text.UTF8Encoding $false))
    L 'RustDesk: id e chaves removidos'
}
Get-ChildItem 'C:\Users\*\AppData\Roaming\RustDesk\config\RustDesk.toml' -ErrorAction SilentlyContinue | ForEach-Object {
    $t = [IO.File]::ReadAllLines($_.FullName) | Where-Object { $_ -notmatch '^\s*(id|enc_id|key_confirmed)\s*=' }
    [IO.File]::WriteAllLines($_.FullName, [string[]]$t, (New-Object Text.UTF8Encoding $false))
}

# 4. Agente VDE-CE: nenhum estado herdado (cada PC se registra sozinho)
Remove-Item 'C:\ProgramData\VDE-CE' -Recurse -Force -ErrorAction SilentlyContinue

# 5. Contas: o sysprep desativa a conta interna Administrador; ela volta ativa, com a mesma senha
& net.exe user Administrador /active:yes | Out-Null
L "Administrador ativo: $((Get-LocalUser Administrador).Enabled)"

# servicos ficam automaticos e iniciam sem esperar (no specialize sobem de fato no proximo boot)
foreach ($s in 'AnyDesk', 'RustDesk') { & sc.exe config $s start= auto 2>&1 | Out-Null; & sc.exe start $s 2>&1 | Out-Null }
New-Item $marker -Force | Out-Null
Set-ItemProperty $marker -Name PrimeiroBoot -Value (Get-Date -Format 's')
Unregister-ScheduledTask -TaskName 'EEEP-PrimeiroBoot' -Confirm:$false -ErrorAction SilentlyContinue
L 'fim'
