#Requires -Version 5.1

[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdministrator) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments
    exit
}

Set-Location -LiteralPath $PSScriptRoot
Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -File -Filter '*.ps1' -ErrorAction SilentlyContinue |
    Unblock-File -ErrorAction SilentlyContinue
Clear-Host
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' INSTALAÇÃO DO LABORATÓRIO - WINDOWS 11 (kit revisão 4)' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'O procedimento instala os aplicativos, Flutter/Dart, Android SDK,'
Write-Host 'atalhos web e modelos para Spring/Selenium. Kali Linux não será'
Write-Host 'instalado; o pacote instala apenas o Oracle VirtualBox.'
Write-Host 'Os componentes serão disponibilizados para todos os usuários locais.'
Write-Host 'O Postman e as extensões serão concluídos automaticamente em cada perfil.'
Write-Host 'Antes dos programas, o App Installer/WinGet será atualizado e testado.'
Write-Host ''
Write-Host 'Antes de continuar:' -ForegroundColor Yellow
Write-Host '  - mantenha a máquina ligada, conectada à Internet e à energia;'
Write-Host '  - feche VS Code, Android Studio, navegadores e instaladores;'
Write-Host '  - reserve pelo menos 35 GB livres;'
Write-Host '  - a confirmação abaixo autoriza os termos dos fornecedores e do Android SDK;'
Write-Host '  - no FINAL, o instalador do Nmap/Npcap abre com janela: clique em Avançar.'
Write-Host '    (a versão gratuita não instala em modo silencioso)'
Write-Host ''

$rebootKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
)
if (@($rebootKeys | Where-Object { Test-Path -LiteralPath $_ }).Count) {
    Write-Host 'ATENÇÃO: o Windows está aguardando reinicialização por causa de atualizações.' -ForegroundColor Red
    Write-Host 'Instaladores como Visual C++, VirtualBox e PostgreSQL costumam falhar nessa situação.' -ForegroundColor Red
    Write-Host 'Recomendado: feche, reinicie a máquina e execute o kit de novo.' -ForegroundColor Red
    Write-Host ''
}

$packet = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Pacotes'), $PSScriptRoot -Filter '*Packet*Tracer*.exe' -File -ErrorAction SilentlyContinue)
if ($packet.Count -eq 0) {
    Write-Host 'ATENÇÃO: o instalador do Packet Tracer ainda não está na pasta Pacotes.' -ForegroundColor Yellow
}

$visualg = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Pacotes'), $PSScriptRoot -Filter 'visualg*.rar' -File -ErrorAction SilentlyContinue)
if ($visualg.Count -eq 0) {
    Write-Host 'ATENÇÃO: o arquivo visualg3.0.7.rar ainda não está na pasta Pacotes.' -ForegroundColor Yellow
}

Write-Host ''
$confirmation = Read-Host 'Digite INSTALAR para iniciar'
if ($confirmation -cne 'INSTALAR') {
    Write-Host 'Operação cancelada.' -ForegroundColor Yellow
    Read-Host 'Pressione Enter para fechar'
    exit 1
}

Write-Host ''
Write-Host 'Informe a senha que será usada pela conta postgres nesta máquina.' -ForegroundColor Yellow
Write-Host 'A senha fica somente na memória durante a instalação.' -ForegroundColor DarkGray
$postgresCredential = Get-Credential -UserName 'postgres' -Message 'Senha inicial do PostgreSQL'
if (-not $postgresCredential) {
    throw 'A credencial do PostgreSQL não foi informada.'
}

$results = @(& (Join-Path $PSScriptRoot 'Install-LabSoftware.ps1') `
    -AcceptPackageAgreements `
    -AcceptAndroidSdkLicenses `
    -PostgresCredential $postgresCredential)

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' RESULTADO' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
$results | Format-Table -AutoSize -Property Component, Status, Details

$failures = @($results | Where-Object { $_.Status -eq 'FALHA' })
$pending = @($results | Where-Object { $_.Status -eq 'PENDENTE' })
Write-Host ''
Write-Host ("Falhas: {0} | Pendências: {1}" -f $failures.Count, $pending.Count) -ForegroundColor $(if ($failures.Count) { 'Red' } elseif ($pending.Count) { 'Yellow' } else { 'Green' })
Write-Host 'Os logs e CSVs ficam em C:\ProgramData\LabSetup\Logs.' -ForegroundColor Cyan
Write-Host 'Reinicie o computador ao final, principalmente por causa do VirtualBox e drivers.' -ForegroundColor Yellow
Write-Host 'No primeiro acesso de cada usuário, aguarde a configuração automática do Postman e do VS Code.' -ForegroundColor Yellow
Read-Host 'Pressione Enter para fechar'

if ($failures.Count -gt 0) { exit 2 }
if ($pending.Count -gt 0) { exit 1 }
exit 0
