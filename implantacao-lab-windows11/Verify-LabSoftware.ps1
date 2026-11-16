#Requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateRange(30, 37)]
    [int]$AndroidApiLevel = 36
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'SilentlyContinue'
$results = @()

function Add-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Component,
        [Parameter(Mandatory = $true)][bool]$Passed,
        [Parameter(Mandatory = $true)][string]$Details,
        [string]$PendingDetails
    )

    $status = if ($Passed) { 'OK' } else { 'PENDENTE' }
    $detailText = if (-not $Passed -and $PendingDetails) { $PendingDetails } else { $Details }
    $script:results += [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        Component    = $Component
        Status       = $status
        Details      = $detailText
        Timestamp    = (Get-Date).ToString('s')
    }
}

function Test-AnyPath {
    param([Parameter(Mandatory = $true)][string[]]$Patterns)
    foreach ($pattern in $Patterns) {
        if (Test-Path -Path $pattern) { return $true }
    }
    return $false
}

function Test-RecursiveFile {
    param(
        [Parameter(Mandatory = $true)][string[]]$Roots,
        [Parameter(Mandatory = $true)][string]$NamePattern
    )

    foreach ($root in $Roots) {
        if (Get-ChildItem -LiteralPath $root -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like $NamePattern } |
            Select-Object -First 1) {
            return $true
        }
    }
    return $false
}

function Get-InstalledDisplayNames {
    param([Parameter(Mandatory = $true)][Microsoft.Win32.RegistryHive]$Hive)

    $names = New-Object 'System.Collections.Generic.List[string]'
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
                            [void]$names.Add($name)
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
    return @($names | Sort-Object -Unique)
}

function Get-WorkingWingetVersion {
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
        try {
            $global:LASTEXITCODE = -1
            $output = @(& $candidate '--version' 2>&1)
            if ($LASTEXITCODE -eq 0) {
                $version = $output | Where-Object { [string]$_ -match '^v?[0-9]+\.' } | Select-Object -First 1
                if ($version) { return [string]$version }
            }
        }
        catch { }
    }
    return $null
}

$machineDisplayNames = @(Get-InstalledDisplayNames -Hive ([Microsoft.Win32.RegistryHive]::LocalMachine))
$userDisplayNames = @(Get-InstalledDisplayNames -Hive ([Microsoft.Win32.RegistryHive]::CurrentUser))

function Test-MachineAppName {
    param([Parameter(Mandatory = $true)][string]$Pattern)
    return [bool](@($machineDisplayNames | Where-Object { $_ -like $Pattern }).Count)
}

function Test-UserAppName {
    param([Parameter(Mandatory = $true)][string]$Pattern)
    return [bool](@($userDisplayNames | Where-Object { $_ -like $Pattern }).Count)
}

$commonDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
$commonDocuments = [Environment]::GetFolderPath('CommonDocuments')
if (-not $commonDesktop) { $commonDesktop = Join-Path $env:PUBLIC 'Desktop' }
if (-not $commonDocuments) { $commonDocuments = Join-Path $env:PUBLIC 'Documents' }

$vcx64 = Test-MachineAppName '*Visual C++ 2015-20* Redistributable (x64)*'
Add-Check 'Visual C++ 2015+ (x64)' $vcx64 'Runtime localizado.' 'Runtime Visual C++ x64 não localizado.'
$wingetVersion = Get-WorkingWingetVersion
Add-Check 'WinGet' ([bool]$wingetVersion) "Execução validada: $wingetVersion" 'winget.exe não inicia no perfil atual.'
$libreOfficeAvailable = (Test-MachineAppName '*LibreOffice*') -or (Test-AnyPath @('C:\Program Files\LibreOffice\program\soffice.exe'))
Add-Check 'LibreOffice (máquina)' $libreOfficeAvailable 'Aplicativo compartilhado localizado.' 'LibreOffice não localizado no escopo da máquina.'
Add-Check 'VisuAlg 3' (Test-RecursiveFile -Roots @('C:\Program Files\VisuAlg', 'C:\VisuAlg') -NamePattern '*visualg*.exe') 'Executável localizado.' 'Arquivo manual ainda não implantado.'
Add-Check 'XAMPP' (Test-AnyPath @('C:\xampp\xampp-control.exe')) 'Painel XAMPP localizado.' 'C:\xampp\xampp-control.exe não localizado.'
Add-Check 'PostgreSQL' ([bool](Get-Service -Name 'postgresql*')) 'Serviço PostgreSQL localizado.' 'Serviço PostgreSQL não localizado.'
Add-Check 'Figma Web' (Test-AnyPath @((Join-Path $commonDesktop 'Figma Web.url'), (Join-Path $commonDesktop 'Laboratorio de Informatica\Figma Web.url'))) 'Atalho web público localizado.' 'Atalho Figma Web não localizado.'
Add-Check 'Visual Studio Code (máquina)' (Test-AnyPath @('C:\Program Files\Microsoft VS Code\Code.exe')) 'Executável compartilhado localizado.' 'VS Code não foi instalado no escopo da máquina.'
$postmanAvailable = (Test-UserAppName '*Postman*') -or (Test-MachineAppName '*Postman*') -or (Test-AnyPath @("$env:LOCALAPPDATA\Postman\Postman.exe", 'C:\Program Files\Postman\Postman.exe'))
Add-Check 'Postman (perfil atual)' $postmanAvailable 'Aplicativo disponível no perfil atual.' 'Será instalado automaticamente neste perfil; entre novamente ou execute CONFIGURAR-USUARIO.cmd.'
$runConfiguration = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'LabSetupConfigurarUsuario' -ErrorAction SilentlyContinue
Add-Check 'Configuração automática por usuário' ([bool]$runConfiguration) 'Rotina registrada para todos os perfis.' 'Rotina automática por usuário não localizada.'
Add-Check 'Java JDK/SDK' ([bool](Get-Command 'java.exe')) 'java.exe disponível no PATH.' 'java.exe não está no PATH.'
Add-Check 'Apache Maven' ([bool](Get-Command 'mvn.cmd')) 'mvn.cmd disponível no PATH.' 'Maven não está no PATH.'
Add-Check 'Apache NetBeans (máquina)' ((Test-MachineAppName '*NetBeans*') -or (Test-AnyPath @('C:\Program Files\NetBeans*\bin\netbeans64.exe', 'C:\Program Files\Apache-NetBeans*\netbeans\bin\netbeans64.exe')) -or (Test-RecursiveFile -Roots @('C:\Program Files\WinGet\Packages') -NamePattern 'netbeans64.exe')) 'Aplicativo compartilhado localizado.' 'NetBeans não localizado no escopo da máquina.'
Add-Check 'Eclipse IDE (máquina)' ((Test-MachineAppName '*Eclipse IDE*') -or (Test-AnyPath @('C:\Program Files\Eclipse*\eclipse.exe', 'C:\Program Files\LabApps\Eclipse\eclipse.exe', 'C:\Program Files\LabApps\Eclipse\eclipse\eclipse.exe')) -or (Test-RecursiveFile -Roots @('C:\Program Files\WinGet\Packages') -NamePattern 'eclipse.exe')) 'Executável compartilhado localizado.' 'Eclipse não localizado no escopo da máquina.'
Add-Check 'Cisco Packet Tracer (máquina)' (Test-MachineAppName '*Packet Tracer*') 'Aplicativo registrado para todos os usuários.' 'Instalador oficial manual ainda não implantado.'
Add-Check 'Nmap (máquina)' ((Test-MachineAppName '*Nmap*') -or (Test-AnyPath @('C:\Program Files (x86)\Nmap\nmap.exe', 'C:\Program Files\Nmap\nmap.exe'))) 'Aplicativo compartilhado localizado.' 'Nmap não localizado; rode o instalador (etapa com cliques).'
Add-Check 'Npcap' ((Test-Path -LiteralPath (Join-Path $env:SystemRoot 'System32\Npcap\wpcap.dll')) -or [bool](Get-Service -Name 'npcap')) 'Driver de captura localizado.' 'Npcap não localizado; o Nmap não captura pacotes.'
Add-Check 'Oracle VirtualBox' (Test-AnyPath @('C:\Program Files\Oracle\VirtualBox\VBoxManage.exe')) 'VBoxManage localizado.' 'VirtualBox não localizado.'
Add-Check 'Arduino IDE (máquina)' ((Test-MachineAppName '*Arduino IDE*') -or (Test-AnyPath @('C:\Program Files\Arduino IDE\Arduino IDE.exe', 'C:\Program Files\arduino-ide\Arduino IDE.exe'))) 'Aplicativo compartilhado localizado.' 'Arduino IDE não foi instalado no escopo da máquina.'
Add-Check 'Flutter' (Test-Path -LiteralPath 'C:\Dev\flutter\bin\flutter.bat') 'Flutter SDK localizado.' 'Flutter SDK não localizado.'
Add-Check 'Dart' (Test-Path -LiteralPath 'C:\Dev\flutter\bin\dart.bat') 'Dart incluído no Flutter SDK.' 'dart.bat não localizado dentro do Flutter SDK.'
Add-Check 'Android Studio (máquina)' ((Test-MachineAppName '*Android Studio*') -or (Test-AnyPath @('C:\Program Files\Android\Android Studio\bin\studio64.exe'))) 'Aplicativo compartilhado localizado.' 'Android Studio não localizado no escopo da máquina.'
Add-Check 'Android SDK' ((Test-Path -LiteralPath 'C:\Android\platform-tools\adb.exe') -and (Test-Path -LiteralPath "C:\Android\platforms\android-$AndroidApiLevel")) "API $AndroidApiLevel e adb localizados." 'Componentes/aceites do Android SDK pendentes.'
Add-Check 'Spring Framework' (Test-Path -LiteralPath (Join-Path $commonDocuments 'Lab-Templates\Spring\LEIA-ME.md')) 'Modelo e Spring Initializr configurados.' 'Modelo Spring não localizado.'
Add-Check 'Selenium' (Test-Path -LiteralPath (Join-Path $commonDocuments 'Lab-Templates\SeleniumJava\pom.xml')) 'Modelo Maven com Selenium localizado.' 'Modelo Selenium não localizado.'

$results
