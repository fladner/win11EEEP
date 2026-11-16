#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
  Desativa os avisos recorrentes do Windows 11 para TODOS os perfis locais:
    - "Vamos concluir a configuracao do seu dispositivo" (SCOOBE)
    - pedidos para entrar com conta Microsoft (menu Iniciar / Configuracoes)
    - pedidos de backup do OneDrive / Backup do Windows
    - sugestoes, dicas e aplicativos "recomendados"
  Nao remove nem altera contas de usuario, senhas ou as GPOs ja existentes.
  Executar dentro da imagem (VM), como Administrador, com os outros usuarios deslogados.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

function Set-Reg {
    param([string]$Path, [string]$Name, [int]$Value)
    & reg.exe add $Path /v $Name /t REG_DWORD /d $Value /f | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Warning "falhou: $Path\$Name" }
}

# ---------- Maquina (vale para qualquer usuario, inclusive os criados depois) ----------
$m = 'HKLM\SOFTWARE\Policies\Microsoft\Windows'
Set-Reg "$m\CloudContent" DisableWindowsConsumerFeatures 1
Set-Reg "$m\CloudContent" DisableConsumerAccountStateContent 1
Set-Reg "$m\CloudContent" DisableSoftLanding 1
Set-Reg "$m\CloudContent" DisableCloudOptimizedContent 1
Set-Reg "$m\OOBE" DisablePrivacyExperience 1
# OneDrive: nao oferecer "fazer backup das pastas" (Area de Trabalho/Documentos/Imagens)
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\OneDrive' KFMBlockOptIn 1
# OneDrive desativado na maquina (laboratorio com conta compartilhada): sem sincronizacao nem avisos de backup.
# Para reativar: apagar o valor DisableFileSyncNGSC.
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive' DisableFileSyncNGSC 1
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\OneDrive' PreventNetworkTrafficPreUserSignIn 1
Get-Process OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
# Nao exibir a animacao/boas-vindas de primeiro logon nem a tela pos-atualizacao
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' EnableFirstLogonAnimation 0

# ---------- Por usuario ----------
$perUser = @(
    @('Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement', 'ScoobeSystemSettingEnabled', 0),
    @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-310093Enabled', 0),
    @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-338389Enabled', 0),
    @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-338393Enabled', 0),
    @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-353694Enabled', 0),
    @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-353696Enabled', 0),
    @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SoftLandingEnabled', 0),
    @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SystemPaneSuggestionsEnabled', 0),
    @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SilentInstalledAppsEnabled', 0),
    @('Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'Start_AccountNotifications', 0),
    @('Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'Start_IrisRecommendations', 0),
    @('Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'ShowSyncProviderNotifications', 0),
    @('Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.BackupReminder', 'Enabled', 0),
    @('Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications', 'EnableAccountNotifications', 0),
    @('Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.SkyDrive.Desktop', 'Enabled', 0),
    @('Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\MicrosoftWindows.Client.CBS_cw5n1h2txyewy!WindowsBackup', 'Enabled', 0)
)

function Set-UserHive([string]$Root) {
    foreach ($e in $perUser) { Set-Reg "$Root\$($e[0])" $e[1] $e[2] }
    # OneDrive nao inicia com o logon (nem e instalado em perfis novos, no caso do perfil Default)
    foreach ($v in 'OneDrive', 'OneDriveSetup') { & cmd.exe /c "reg delete `"$Root\Software\Microsoft\Windows\CurrentVersion\Run`" /v $v /f >nul 2>&1" }
}

$profiles = Get-CimInstance Win32_UserProfile | Where-Object { -not $_.Special -and $_.LocalPath -like 'C:\Users\*' }
$targets = @($profiles | ForEach-Object { [pscustomobject]@{ Name = Split-Path $_.LocalPath -Leaf; Sid = $_.SID; Hive = Join-Path $_.LocalPath 'NTUSER.DAT' } })
$targets += [pscustomobject]@{ Name = 'Default'; Sid = $null; Hive = 'C:\Users\Default\NTUSER.DAT' }

foreach ($t in $targets) {
    if ($t.Sid -and (Test-Path "Registry::HKEY_USERS\$($t.Sid)")) {
        Set-UserHive "HKU\$($t.Sid)"
        Write-Host "OK (perfil carregado): $($t.Name)"
        continue
    }
    if (-not (Test-Path -LiteralPath $t.Hive)) { Write-Warning "sem NTUSER.DAT: $($t.Name)"; continue }
    $mount = "HKU\EEEP_$($t.Name -replace '[^A-Za-z0-9]', '')"
    & reg.exe load $mount $t.Hive | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Warning "nao foi possivel carregar o perfil $($t.Name) (usuario logado?)"; continue }
    try { Set-UserHive $mount; Write-Host "OK: $($t.Name)" }
    finally { [gc]::Collect(); Start-Sleep -Milliseconds 500; & reg.exe unload $mount | Out-Null }
}
Write-Host 'Concluido.' -ForegroundColor Green
