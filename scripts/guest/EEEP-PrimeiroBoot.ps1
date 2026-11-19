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

# 2. AnyDesk: sem ID/chaves herdados -> o servico pede um ID novo ao iniciar.
#    A identidade fica em service.conf (chaves) E em system.conf (ad.anynet.id, fpr, inst.id...): sem limpar o
#    system.conf todos os PCs ficam com o MESMO ID. Licenca e permissoes do system.conf sao preservadas.
#    Decisao do usuario (17/11): apagar TUDO de identidade e senha (service.conf + system.conf).
Parar AnyDesk AnyDesk
Remove-Item 'C:\ProgramData\AnyDesk\service.conf*', 'C:\ProgramData\AnyDesk\system.conf*' -Force -ErrorAction SilentlyContinue
L "AnyDesk: configuracao apagada ($(-not (Test-Path 'C:\ProgramData\AnyDesk\system.conf')))"

# 3. RustDesk: decisao do usuario (17/11): apagar TUDO de identidade e senha. RustDesk.toml (id, chaves, senha
#    permanente) sai inteiro, no servico e nos perfis; do RustDesk2.toml sai o unlock_pin e fica o servidor
#    (rendezvous_server e demais opcoes, que nao sao senha nem ID).
Parar RustDesk rustdesk
$cfgs = @('C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config') + @(Get-ChildItem 'C:\Users\*\AppData\Roaming\RustDesk\config' -Directory -ErrorAction SilentlyContinue | ForEach-Object FullName)
foreach ($c in $cfgs) {
    Remove-Item "$c\RustDesk.toml" -Force -ErrorAction SilentlyContinue
    $t2 = "$c\RustDesk2.toml"
    if (Test-Path $t2) {
        $t = [IO.File]::ReadAllLines($t2) | Where-Object { $_ -notmatch '^\s*unlock_pin\s*=' }
        [IO.File]::WriteAllLines($t2, [string[]]$t, (New-Object Text.UTF8Encoding $false))
    }
}
L "RustDesk: id, chaves e senha apagados ($(-not (Test-Path 'C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml')))"

# 4. Agente VDE-CE: nenhum estado herdado (cada PC se registra sozinho)
Remove-Item 'C:\ProgramData\VDE-CE' -Recurse -Force -ErrorAction SilentlyContinue

# 5. Contas: o sysprep desativa a conta interna Administrador; ela volta ativa, com a mesma senha
& net.exe user Administrador /active:yes | Out-Null
L "Administrador ativo: $((Get-LocalUser Administrador).Enabled)"

# 6. Energia (pedido do usuario, 18/11): nunca suspender/hibernar; tela apaga apos 15 minutos
& powercfg.exe /h off 2>&1 | Out-Null
foreach ($m in 'ac', 'dc') {
    & powercfg.exe /change "standby-timeout-$m" 0 2>&1 | Out-Null
    & powercfg.exe /change "hibernate-timeout-$m" 0 2>&1 | Out-Null
    & powercfg.exe /change "monitor-timeout-$m" 15 2>&1 | Out-Null
}
L 'energia: sem suspensao/hibernacao, tela 15 min'

# servicos ficam automaticos e iniciam sem esperar (no specialize sobem de fato no proximo boot)
foreach ($s in 'AnyDesk', 'RustDesk') { & sc.exe config $s start= auto 2>&1 | Out-Null; & sc.exe start $s 2>&1 | Out-Null }
New-Item $marker -Force | Out-Null
Set-ItemProperty $marker -Name PrimeiroBoot -Value (Get-Date -Format 's')
Unregister-ScheduledTask -TaskName 'EEEP-PrimeiroBoot' -Confirm:$false -ErrorAction SilentlyContinue
L 'fim'
