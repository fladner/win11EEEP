#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$Automatic,
    [switch]$Force
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $utf8NoBom
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom
$results = @()
$configurationVersion = '2026.08-all-users-v3'
# Revisão 4 do kit: espera rede e WinGet no primeiro logon, instaladores com tempo
# limite e uma só execução por vez (automática e manual não se atropelam).
$userRoot = Join-Path $env:LOCALAPPDATA 'LabSetup'
$logRoot = Join-Path $userRoot 'Logs'
$markerKey = 'HKCU:\Software\LabSetup'

New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$logPath = Join-Path $logRoot ("configuracao-usuario-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

function Add-UserResult {
    param(
        [Parameter(Mandatory = $true)][string]$Component,
        [Parameter(Mandatory = $true)][ValidateSet('OK', 'FALHA', 'PENDENTE', 'AVISO')][string]$Status,
        [Parameter(Mandatory = $true)][string]$Details
    )
    $script:results += [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        UserName     = "$env:USERDOMAIN\$env:USERNAME"
        Component    = $Component
        Status       = $Status
        Details      = $Details
        Timestamp    = (Get-Date).ToString('s')
    }
}

function ConvertTo-NativeOutputText {
    param([AllowNull()][object]$InputObject)

    if ($InputObject -is [System.Management.Automation.ErrorRecord] -and $InputObject.Exception) {
        $message = [string]$InputObject.Exception.Message
        if (-not [string]::IsNullOrWhiteSpace($message)) {
            return $message
        }
    }
    return [string]$InputObject
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [switch]$Quiet
    )

    $output = New-Object 'System.Collections.Generic.List[string]'
    $previousPreference = $ErrorActionPreference
    $exitCode = -1
    try {
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = -1
        & $FilePath @Arguments 2>&1 | ForEach-Object {
            $text = ConvertTo-NativeOutputText -InputObject $_
            [void]$output.Add($text)
            if (-not $Quiet) { Write-Host "  $text" }
        }
        $exitCode = [int]$LASTEXITCODE
    }
    catch {
        [void]$output.Add($_.Exception.Message)
        $exitCode = -1
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    return [PSCustomObject]@{ ExitCode = $exitCode; Output = [string[]]$output.ToArray() }
}

function Invoke-ProcessWithTimeout {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string]$ArgumentLine,
        [int]$TimeoutMinutes = 15
    )

    # Espera só o processo iniciado. Start-Process -Wait também esperava o
    # Postman que o instalador abre ao terminar, e o logon ficava preso.
    $parameters = @{ FilePath = $FilePath; PassThru = $true; WindowStyle = 'Hidden' }
    if ($ArgumentLine) { $parameters['ArgumentList'] = $ArgumentLine }
    $process = Start-Process @parameters
    $null = $process.Handle
    if (-not $process.WaitForExit($TimeoutMinutes * 60000)) {
        try { $process.Kill() } catch { }
        return -2
    }
    return [int]$process.ExitCode
}

function Wait-Network {
    param([int]$MaxSeconds = 180)

    $deadline = (Get-Date).AddSeconds($MaxSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            if ([System.Net.NetworkInformation.NetworkInterface]::GetIsNetworkAvailable()) {
                [void][System.Net.Dns]::GetHostAddresses('marketplace.visualstudio.com')
                return $true
            }
        }
        catch { }
        Start-Sleep -Seconds 10
    }
    return $false
}

function Get-InstalledDisplayNames {
    param([Parameter(Mandatory = $true)][Microsoft.Win32.RegistryHive]$Hive)

    $displayNames = New-Object 'System.Collections.Generic.List[string]'
    $views = @(
        [Microsoft.Win32.RegistryView]::Registry64,
        [Microsoft.Win32.RegistryView]::Registry32
    )

    foreach ($view in $views) {
        $baseKey = $null
        $uninstallKey = $null
        try {
            $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($Hive, $view)
            $uninstallKey = $baseKey.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')
            if (-not $uninstallKey) { continue }

            foreach ($subKeyName in @($uninstallKey.GetSubKeyNames())) {
                $appKey = $null
                try {
                    $appKey = $uninstallKey.OpenSubKey($subKeyName)
                    if (-not $appKey) { continue }
                    $value = $appKey.GetValue(
                        'DisplayName',
                        $null,
                        [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
                    )
                    if ($null -ne $value) {
                        $name = [string]$value
                        if (-not [string]::IsNullOrWhiteSpace($name)) {
                            [void]$displayNames.Add($name)
                        }
                    }
                }
                catch { }
                finally {
                    if ($appKey) { $appKey.Dispose() }
                }
            }
        }
        catch { }
        finally {
            if ($uninstallKey) { $uninstallKey.Dispose() }
            if ($baseKey) { $baseKey.Dispose() }
        }
    }
    return @($displayNames | Sort-Object -Unique)
}

function Get-WingetExecutable {
    $candidates = New-Object 'System.Collections.Generic.List[string]'
    foreach ($package in @(Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue |
        Sort-Object -Property Version -Descending)) {
        if ($package.InstallLocation) {
            [void]$candidates.Add((Join-Path $package.InstallLocation 'winget.exe'))
        }
    }
    $command = Get-Command 'winget.exe' -ErrorAction SilentlyContinue
    if ($command -and $command.Source) { [void]$candidates.Add($command.Source) }
    [void]$candidates.Add((Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'))

    foreach ($candidate in @($candidates | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $candidate)) { continue }
        $probe = Invoke-NativeCommand -FilePath $candidate -Arguments @('--version') -Quiet
        if ($probe.ExitCode -eq 0) { return $candidate }
    }
    return $null
}

function Wait-WingetExecutable {
    param([int]$MaxSeconds = 300)

    # Em perfil novo o App Installer é registrado alguns minutos após o logon.
    $deadline = (Get-Date).AddSeconds($MaxSeconds)
    do {
        $winget = Get-WingetExecutable
        if ($winget) { return $winget }
        try {
            Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop
        }
        catch { }
        Start-Sleep -Seconds 15
    } while ((Get-Date) -lt $deadline)
    return $null
}

function Test-PostmanInstalled {
    $paths = @(
        (Join-Path $env:LOCALAPPDATA 'Postman\Postman.exe'),
        (Join-Path $env:ProgramFiles 'Postman\Postman.exe')
    )
    if (@($paths | Where-Object { Test-Path -LiteralPath $_ }).Count -gt 0) {
        return $true
    }

    $displayNames = @(
        Get-InstalledDisplayNames -Hive ([Microsoft.Win32.RegistryHive]::CurrentUser)
        Get-InstalledDisplayNames -Hive ([Microsoft.Win32.RegistryHive]::LocalMachine)
    )
    foreach ($displayName in $displayNames) {
        if ($displayName -like '*Postman*') {
            return $true
        }
    }
    return $false
}

function Test-TrustedPostmanInstaller {
    param([Parameter(Mandatory = $true)][string]$Path)

    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    return ($signature.Status -eq 'Valid' -and
        $signature.SignerCertificate -and
        $signature.SignerCertificate.Subject -match 'Postman')
}

function Install-PostmanForCurrentUser {
    if (Test-PostmanInstalled) {
        Add-UserResult -Component 'Postman' -Status 'OK' -Details 'Disponível para o perfil atual.'
        return
    }

    $stagedRoot = Join-Path $env:ProgramData 'LabSetup\UserConfig\Packages\Postman'
    $installer = Get-ChildItem -LiteralPath $stagedRoot -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object -Property LastWriteTime -Descending |
        Where-Object { Test-TrustedPostmanInstaller -Path $_.FullName } |
        Select-Object -First 1

    if ($installer) {
        try {
            $exitCode = Invoke-ProcessWithTimeout -FilePath $installer.FullName -ArgumentLine '--silent' -TimeoutMinutes 15
            for ($attempt = 1; $attempt -le 30 -and -not (Test-PostmanInstalled); $attempt++) {
                Start-Sleep -Seconds 2
            }
            if (Test-PostmanInstalled) {
                Add-UserResult -Component 'Postman' -Status 'OK' -Details 'Instalado automaticamente a partir do pacote local validado.'
                return
            }
            Add-UserResult -Component 'Postman (pacote local)' -Status 'AVISO' -Details "O instalador local retornou $exitCode; tentando pelo WinGet."
        }
        catch {
            Add-UserResult -Component 'Postman (pacote local)' -Status 'AVISO' -Details $_.Exception.Message
        }
    }

    $winget = if ($Automatic) { Wait-WingetExecutable } else { Get-WingetExecutable }
    if (-not $winget) {
        Add-UserResult -Component 'Postman' -Status 'FALHA' -Details 'WinGet não foi localizado e o instalador local não funcionou.'
        return
    }

    $wingetResult = Invoke-NativeCommand -FilePath $winget -Arguments @(
        'install', '--id', 'Postman.Postman', '--exact', '--source', 'winget', '--scope', 'user',
        '--silent', '--disable-interactivity', '--accept-source-agreements', '--accept-package-agreements'
    )
    $exitCode = $wingetResult.ExitCode
    if (Test-PostmanInstalled) {
        Add-UserResult -Component 'Postman' -Status 'OK' -Details 'Instalado automaticamente pelo WinGet no perfil atual.'
    }
    else {
        Add-UserResult -Component 'Postman' -Status 'FALHA' -Details "WinGet retornou $exitCode. A configuração tentará novamente no próximo acesso."
    }
}

function Install-VSCodeExtensions {
    $codeCandidates = @(
        (Join-Path $env:ProgramFiles 'Microsoft VS Code\bin\code.cmd'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd')
    )
    $codeCommand = Get-Command 'code.cmd' -ErrorAction SilentlyContinue
    $code = if ($codeCommand) { $codeCommand.Source } else { $codeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1 }

    if (-not $code) {
        Add-UserResult -Component 'Extensões do VS Code' -Status 'FALHA' -Details 'code.cmd não foi localizado no perfil atual.'
        return
    }

    $extensions = @(
        'vscjava.vscode-java-pack',
        'vmware.vscode-boot-dev-pack',
        'Dart-Code.flutter',
        'Postman.postman-for-vscode'
    )
    $installed = @((Invoke-NativeCommand -FilePath $code -Arguments @('--list-extensions') -Quiet).Output |
        ForEach-Object { $_.Trim().ToLowerInvariant() })
    foreach ($extension in $extensions) {
        if ($installed -contains $extension.ToLowerInvariant()) {
            Add-UserResult -Component $extension -Status 'OK' -Details 'Extensão já instalada no perfil do usuário.'
            continue
        }
        $extensionResult = $null
        for ($attempt = 1; $attempt -le 2; $attempt++) {
            $extensionResult = Invoke-NativeCommand -FilePath $code -Arguments @('--install-extension', $extension)
            if ($extensionResult.ExitCode -eq 0) { break }
            Start-Sleep -Seconds 10
        }
        if ($extensionResult.ExitCode -eq 0) {
            Add-UserResult -Component $extension -Status 'OK' -Details 'Extensão instalada/atualizada no perfil do usuário.'
        }
        else {
            Add-UserResult -Component $extension -Status 'FALHA' `
                -Details "code.cmd retornou $($extensionResult.ExitCode)."
        }
    }
}

function Copy-UserTemplates {
    $commonDocuments = [Environment]::GetFolderPath('CommonDocuments')
    $userDocuments = [Environment]::GetFolderPath('MyDocuments')
    if (-not $commonDocuments) { $commonDocuments = Join-Path $env:PUBLIC 'Documents' }
    if (-not $userDocuments) { $userDocuments = Join-Path $env:USERPROFILE 'Documents' }
    $source = Join-Path $commonDocuments 'Lab-Templates'
    $destination = Join-Path $userDocuments 'Lab-Templates'

    if (-not (Test-Path -LiteralPath $source)) {
        Add-UserResult -Component 'Modelos Spring/Selenium' -Status 'FALHA' -Details 'Os modelos compartilhados não foram localizados.'
        return
    }
    if (-not (Test-Path -LiteralPath $destination)) {
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        Copy-Item -Path (Join-Path $source '*') -Destination $destination -Recurse -Force
    }
    Add-UserResult -Component 'Modelos Spring/Selenium' -Status 'OK' -Details $destination
}

$configuredItem = Get-ItemProperty -Path $markerKey -Name 'ConfigurationVersion' -ErrorAction SilentlyContinue
$configuredVersion = if ($configuredItem) { $configuredItem.ConfigurationVersion } else { $null }
if (-not $Force -and $configuredVersion -eq $configurationVersion) {
    Add-UserResult -Component 'Configuração do perfil' -Status 'OK' -Details 'Este perfil já está atualizado.'
    $results
    exit 0
}

# Uma execução por vez no mesmo perfil.
$mutex = New-Object System.Threading.Mutex($false, 'Local\LabSetupConfigurarUsuario')
$ownsMutex = $false
try { $ownsMutex = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $ownsMutex = $true }
if (-not $ownsMutex) {
    Add-UserResult -Component 'Configuração do perfil' -Status 'AVISO' -Details 'Outra configuração já está em andamento neste perfil.'
    $results
    exit 0
}

$transcriptStarted = $false
try {
    Start-Transcript -LiteralPath $logPath -Force | Out-Null
    $transcriptStarted = $true
}
catch {
    Add-UserResult -Component 'Log do perfil' -Status 'AVISO' -Details 'Não foi possível iniciar o transcript; a configuração continuará.'
}

try {
    if ($Automatic -and -not (Wait-Network)) {
        Add-UserResult -Component 'Rede' -Status 'AVISO' -Details 'Sem Internet após 3 minutos; tentando mesmo assim.'
    }
    Install-PostmanForCurrentUser
    Install-VSCodeExtensions
    Copy-UserTemplates

    $failures = @($results | Where-Object { $_.Status -eq 'FALHA' })
    if ($failures.Count -eq 0) {
        New-Item -Path $markerKey -Force | Out-Null
        New-ItemProperty -Path $markerKey -Name 'ConfigurationVersion' -PropertyType String -Value $configurationVersion -Force | Out-Null
        Add-UserResult -Component 'Configuração do perfil' -Status 'OK' -Details 'Perfil preparado para utilizar as ferramentas do laboratório.'
    }
    else {
        Add-UserResult -Component 'Configuração do perfil' -Status 'PENDENTE' -Details 'Houve falhas; uma nova tentativa ocorrerá no próximo acesso.'
    }
}
catch {
    Add-UserResult -Component 'Configuração do perfil' -Status 'FALHA' -Details $_.Exception.Message
}
finally {
    if ($transcriptStarted) {
        try { Stop-Transcript | Out-Null } catch { }
    }
    try { $mutex.ReleaseMutex() } catch { }
    $mutex.Dispose()
}

$results
