#Requires -Version 5.1

[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$results = @(& (Join-Path $PSScriptRoot 'Verify-LabSoftware.ps1'))
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$logRoot = if ($isAdministrator) {
    'C:\ProgramData\LabSetup\Logs'
}
else {
    Join-Path $env:LOCALAPPDATA 'LabSetup\Logs'
}
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$reportPath = Join-Path $logRoot ("verificacao-{0}-{1}.csv" -f $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMdd-HHmmss'))
$results | Export-Csv -LiteralPath $reportPath -NoTypeInformation -Encoding UTF8

Clear-Host
Write-Host 'VERIFICAÇÃO DO LABORATÓRIO' -ForegroundColor Cyan
$results | Format-Table -AutoSize -Property Component, Status, Details
Write-Host ''
Write-Host "Relatório salvo em: $reportPath" -ForegroundColor Green
Read-Host 'Pressione Enter para fechar'
