#Requires -Version 5.1

# Baixa UMA VEZ, para a pasta Pacotes do kit, tudo o que o Install-LabSoftware.ps1
# instalaria pela Internet. Depois, nas máquinas do laboratório, o kit usa esses
# arquivos e só recorre à Internet para o que estiver faltando.
#
# Rode em qualquer Windows 10/11 com WinGet e boa conexão (pode ser em casa).
# Executar de novo só baixa o que falta; use -Force para renovar as versões.
#
# Android SDK: para gerar android-sdk-api<N>.zip é preciso um JDK 17+ (ou o
# Android Studio) instalado neste computador. Sem ele, essa parte é pulada;
# rode este script de novo na primeira máquina do laboratório depois do kit
# (ela já terá o JDK e a pasta C:\Android pronta para ser copiada).

[CmdletBinding()]
param(
    [ValidateRange(30, 37)]
    [int]$AndroidApiLevel = 36,
    [ValidateSet(16, 17, 18)]
    [int]$PostgresMajor = 18,
    [switch]$SkipAndroidSdk,
    [switch]$Force
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$packageRoot = Join-Path $PSScriptRoot 'Pacotes'
$wingetRoot = Join-Path $packageRoot 'WinGet'
$logRoot = Join-Path $packageRoot 'Logs-download'
New-Item -ItemType Directory -Path $wingetRoot, $logRoot -Force | Out-Null
$results = New-Object 'System.Collections.Generic.List[object]'

function Add-Line {
    param([string]$Item, [string]$Status, [string]$Details)
    $results.Add([PSCustomObject]@{ Item = $Item; Status = $Status; Details = $Details })
    $color = switch ($Status) { 'OK' { 'Green' } 'FALHA' { 'Red' } 'MANUAL' { 'Yellow' } default { 'DarkGray' } }
    Write-Host ("[{0}] {1}: {2}" -f $Status, $Item, $Details) -ForegroundColor $color
}

function Invoke-Logged {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string]$ArgumentLine,
        [Parameter(Mandatory = $true)][string]$LogName,
        [string]$StandardInputFile
    )
    $out = Join-Path $logRoot "$LogName.log"
    $err = Join-Path $logRoot "$LogName.err.log"
    $parameters = @{
        FilePath = $FilePath; NoNewWindow = $true; PassThru = $true
        RedirectStandardOutput = $out; RedirectStandardError = $err
    }
    if ($ArgumentLine) { $parameters['ArgumentList'] = $ArgumentLine }
    if ($StandardInputFile) { $parameters['RedirectStandardInput'] = $StandardInputFile }
    $process = Start-Process @parameters
    $null = $process.Handle
    $process.WaitForExit()
    return [int]$process.ExitCode
}

function Get-RemoteText {
    param([Parameter(Mandatory = $true)][string]$Uri)
    $content = (Invoke-WebRequest -UseBasicParsing -Uri $Uri -TimeoutSec 120).Content
    if ($content -is [byte[]]) { $content = [Text.Encoding]::UTF8.GetString($content) }
    return ([string]$content).TrimStart([char]0xFEFF)
}

function Save-File {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$Destination,
        [string]$ExpectedHash,
        [string]$Algorithm = 'SHA256'
    )
    if ((Test-Path -LiteralPath $Destination) -and -not $Force) {
        if (-not $ExpectedHash -or (Get-FileHash -LiteralPath $Destination -Algorithm $Algorithm).Hash -ieq $ExpectedHash) {
            return 'já estava baixado'
        }
    }
    New-Item -ItemType Directory -Path (Split-Path -Path $Destination -Parent) -Force | Out-Null
    $partial = "$Destination.part"
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
        try {
            Write-Host "    Baixando $Uri" -ForegroundColor DarkGray
            try {
                Start-BitsTransfer -Source $Uri -Destination $partial -ErrorAction Stop
            }
            catch {
                Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $partial -TimeoutSec 900
            }
            if ($ExpectedHash -and (Get-FileHash -LiteralPath $partial -Algorithm $Algorithm).Hash -ine $ExpectedHash) {
                throw "hash $Algorithm não confere"
            }
            Move-Item -LiteralPath $partial -Destination $Destination -Force
            return 'baixado'
        }
        catch {
            Write-Warning "Tentativa $attempt falhou: $($_.Exception.Message)"
            Start-Sleep -Seconds (5 * $attempt)
        }
    }
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    throw "não foi possível baixar $Uri"
}

function Get-WingetPath {
    $command = Get-Command 'winget.exe' -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $alias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path -LiteralPath $alias) { return $alias }
    return $null
}

function Get-InstallerFile {
    param([Parameter(Mandatory = $true)][string]$Directory)
    if (-not (Test-Path -LiteralPath $Directory)) { return $null }
    return Get-ChildItem -LiteralPath $Directory -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @('.exe', '.msi', '.zip') -and $_.FullName -notmatch '\\Dependencies\\' } |
        Select-Object -First 1
}

Clear-Host
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' DOWNLOAD DOS PACOTES DO LABORATÓRIO (uma vez só)' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host "Destino: $packageRoot"
Write-Host 'São vários gigabytes; deixe o computador ligado e conectado.'
Write-Host ''

# ---------------------------------------------------------------------------
# 1. Instaladores obtidos pelo WinGet (mesmas versões e hashes do catálogo)
# ---------------------------------------------------------------------------
$winget = Get-WingetPath
$wingetPackages = @(
    @{ Id = 'Microsoft.VCRedist.2015+.x64'; Arch = 'x64' },
    @{ Id = 'Microsoft.VCRedist.2015+.x86'; Arch = 'x86' },
    @{ Id = '7zip.7zip'; Arch = 'x64'; Type = 'wix' },
    @{ Id = 'Git.Git'; Arch = 'x64'; Scope = 'machine' },
    @{ Id = 'EclipseAdoptium.Temurin.21.JDK'; Arch = 'x64' },
    @{ Id = 'TheDocumentFoundation.LibreOffice'; Arch = 'x64' },
    @{ Id = 'ApacheFriends.Xampp.8.2'; Arch = 'x64' },
    @{ Id = "PostgreSQL.PostgreSQL.$PostgresMajor"; Arch = 'x64' },
    @{ Id = 'Microsoft.VisualStudioCode'; Arch = 'x64'; Scope = 'machine' },
    @{ Id = 'Apache.NetBeans'; Arch = 'x64' },
    @{ Id = 'EclipseFoundation.Eclipse.Java'; Arch = 'x64' },
    @{ Id = 'Oracle.VirtualBox'; Arch = 'x64' },
    @{ Id = 'ArduinoSA.IDE.stable'; Arch = 'x64'; Type = 'wix' },
    @{ Id = 'Google.AndroidStudio'; Arch = 'x64' },
    @{ Id = 'Postman.Postman'; Arch = 'x64' }
)

if (-not $winget) {
    Add-Line 'WinGet' 'FALHA' 'winget.exe não encontrado neste computador; os instaladores do item 1 não foram baixados.'
}
else {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $winget source update --name winget --disable-interactivity 2>&1 | Out-Null
    $ErrorActionPreference = $previous

    foreach ($package in $wingetPackages) {
        $id = $package.Id
        $directory = Join-Path $wingetRoot $id
        $existing = Get-InstallerFile -Directory $directory
        if ($existing -and -not $Force) {
            Add-Line $id 'OK' "já estava baixado ($($existing.Name))"
            continue
        }
        if (Test-Path -LiteralPath $directory) { Remove-Item -LiteralPath $directory -Recurse -Force }
        New-Item -ItemType Directory -Path $directory -Force | Out-Null

        $base = "download --id `"$id`" --exact --source winget --download-directory `"$directory`" --architecture $($package.Arch) --skip-dependencies --accept-source-agreements --accept-package-agreements --disable-interactivity"
        $variants = @()
        $extra = ''
        if ($package.ContainsKey('Scope')) { $extra += " --scope $($package.Scope)" }
        if ($package.ContainsKey('Type')) { $extra += " --installer-type $($package.Type)" }
        if ($extra) { $variants += "$base$extra" }
        $variants += $base
        # Versões antigas do WinGet não conhecem --skip-dependencies no download;
        # o kit ignora a subpasta Dependencies de qualquer forma.
        $variants += ($base -replace ' --skip-dependencies', '')

        Write-Host "Baixando $id..." -ForegroundColor Cyan
        $code = -1
        foreach ($arguments in $variants) {
            $code = Invoke-Logged -FilePath $winget -ArgumentLine $arguments -LogName ($id -replace '[^A-Za-z0-9.]', '_')
            if (Get-InstallerFile -Directory $directory) { break }
        }
        $file = Get-InstallerFile -Directory $directory
        if ($file) {
            Add-Line $id 'OK' $file.Name
        }
        else {
            Add-Line $id 'FALHA' ("winget download retornou {0} (0x{0:X8}); veja Pacotes\Logs-download." -f $code)
        }
    }
}

# ---------------------------------------------------------------------------
# 2. Arquivos baixados direto das fontes oficiais
# ---------------------------------------------------------------------------
try {
    $listing = Get-RemoteText -Uri 'https://dlcdn.apache.org/maven/maven-3/'
    $version = @([Regex]::Matches($listing, 'href="(3\.[0-9]+\.[0-9]+)/"') | ForEach-Object { $_.Groups[1].Value } |
        Sort-Object -Unique | Sort-Object -Property { [Version]$_ } -Descending)[0]
    $fileName = "apache-maven-$version-bin.zip"
    $url = "https://dlcdn.apache.org/maven/maven-3/$version/binaries/$fileName"
    $hash = ((Get-RemoteText -Uri "$url.sha512").Trim() -split '\s+')[0]
    $target = Join-Path $packageRoot "Maven\$fileName"
    $state = Save-File -Uri $url -Destination $target -ExpectedHash $hash -Algorithm SHA512
    Set-Content -LiteralPath "$target.sha512" -Value $hash -Encoding ASCII
    Add-Line 'Apache Maven' 'OK' "$fileName ($state)"
}
catch { Add-Line 'Apache Maven' 'FALHA' $_.Exception.Message }

try {
    $index = Invoke-RestMethod -UseBasicParsing -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
    $release = $index.releases | Where-Object { $_.hash -eq $index.current_release.stable } | Select-Object -First 1
    $fileName = [IO.Path]::GetFileName([string]$release.archive)
    $target = Join-Path $packageRoot "Flutter\$fileName"
    $state = Save-File -Uri ("{0}/{1}" -f $index.base_url.TrimEnd('/'), $release.archive) -Destination $target -ExpectedHash ([string]$release.sha256)
    Add-Line 'Flutter + Dart' 'OK' "$fileName ($state)"
}
catch { Add-Line 'Flutter + Dart' 'FALHA' $_.Exception.Message }

try {
    $listing = Get-RemoteText -Uri 'https://nmap.org/dist/'
    $version = @([Regex]::Matches($listing, 'nmap-([0-9]+\.[0-9]+)-setup\.exe') | ForEach-Object { $_.Groups[1].Value } |
        Sort-Object -Unique | Sort-Object -Property { [Version]$_ } -Descending)[0]
    $fileName = "nmap-$version-setup.exe"
    $state = Save-File -Uri "https://nmap.org/dist/$fileName" -Destination (Join-Path $packageRoot "Nmap\$fileName")
    Add-Line 'Nmap' 'OK' "$fileName ($state)"
}
catch { Add-Line 'Nmap' 'FALHA' $_.Exception.Message }

$toolsZip = $null
try {
    $xml = [xml](Get-RemoteText -Uri 'https://dl.google.com/android/repository/repository2-3.xml')
    foreach ($node in $xml.SelectNodes("//*[local-name()='remotePackage'][@path='cmdline-tools;latest']")) {
        $channel = $node.SelectSingleNode("*[local-name()='channelRef']")
        if ($channel -and $channel.GetAttribute('ref') -ne 'channel-0') { continue }
        foreach ($archive in $node.SelectNodes(".//*[local-name()='archive']")) {
            $urlNode = $archive.SelectSingleNode(".//*[local-name()='complete']/*[local-name()='url']")
            $sumNode = $archive.SelectSingleNode(".//*[local-name()='complete']/*[local-name()='checksum']")
            if ($urlNode -and $urlNode.InnerText -match '-win-') {
                $fileName = $urlNode.InnerText.Trim()
                $toolsZip = Join-Path $packageRoot "Android\$fileName"
                $state = Save-File -Uri "https://dl.google.com/android/repository/$fileName" -Destination $toolsZip `
                    -ExpectedHash $sumNode.InnerText.Trim() -Algorithm SHA1
                Add-Line 'Android Command-line Tools' 'OK' "$fileName ($state)"
                break
            }
        }
        if ($toolsZip) { break }
    }
    if (-not $toolsZip) { throw 'arquivo para Windows não encontrado no índice oficial.' }
}
catch { Add-Line 'Android Command-line Tools' 'FALHA' $_.Exception.Message; $toolsZip = $null }

$visualgTarget = Join-Path $packageRoot 'visualg3.0.7.rar'
$visualgAny = Get-ChildItem -LiteralPath $packageRoot -Filter 'visualg*.rar' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($visualgAny) {
    Add-Line 'VisuAlg 3' 'OK' "já estava em Pacotes ($($visualgAny.Name))"
}
else {
    try {
        [void](Save-File -Uri 'https://sourceforge.net/projects/visualg30/files/visualg3.0.7.rar/download' -Destination $visualgTarget)
        $header = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($visualgTarget), 0, 4)
        if ($header -ne 'Rar!') {
            Remove-Item -LiteralPath $visualgTarget -Force
            throw 'o SourceForge devolveu uma página em vez do arquivo.'
        }
        Add-Line 'VisuAlg 3' 'OK' 'visualg3.0.7.rar baixado'
    }
    catch {
        Add-Line 'VisuAlg 3' 'MANUAL' "Baixe pelo navegador: https://sourceforge.net/projects/visualg30/files/visualg3.0.7.rar/download ($($_.Exception.Message))"
    }
}

$packet = Get-ChildItem -LiteralPath $packageRoot -Filter '*Packet*Tracer*.exe' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($packet) {
    Add-Line 'Cisco Packet Tracer' 'OK' "já estava em Pacotes ($($packet.Name))"
}
else {
    Add-Line 'Cisco Packet Tracer' 'MANUAL' 'Exige login: baixe em https://www.netacad.com (Resources > Packet Tracer) e coloque o EXE em Pacotes.'
}

# ---------------------------------------------------------------------------
# 3. Android SDK completo (plataforma, build-tools, emulator, platform-tools)
# ---------------------------------------------------------------------------
$sdkZip = Join-Path $packageRoot "Android\android-sdk-api$AndroidApiLevel.zip"
$tar = Join-Path $env:SystemRoot 'System32\tar.exe'
if ($SkipAndroidSdk) {
    Add-Line 'Android SDK' 'IGNORADO' 'Opção -SkipAndroidSdk utilizada.'
}
elseif ((Test-Path -LiteralPath $sdkZip) -and -not $Force) {
    Add-Line 'Android SDK' 'OK' "já estava baixado ($([IO.Path]::GetFileName($sdkZip)))"
}
elseif (-not (Test-Path -LiteralPath $tar)) {
    Add-Line 'Android SDK' 'FALHA' 'tar.exe não existe neste Windows; não é possível gerar o ZIP do SDK.'
}
else {
    try {
        $sdkRoot = $null
        $installedSdk = 'C:\Android'
        $needed = @('platform-tools\adb.exe', "platforms\android-$AndroidApiLevel", "build-tools\$AndroidApiLevel.0.0", 'emulator\emulator.exe')
        if (@($needed | Where-Object { -not (Test-Path -LiteralPath (Join-Path $installedSdk $_)) }).Count -eq 0) {
            $sdkRoot = $installedSdk
            Write-Host 'Usando o Android SDK já instalado em C:\Android.' -ForegroundColor Cyan
        }
        else {
            $javaHome = $null
            $candidates = @($env:JAVA_HOME)
            foreach ($root in @('C:\Program Files\Eclipse Adoptium', 'C:\Program Files\Java', 'C:\Program Files\Microsoft')) {
                if (Test-Path -LiteralPath $root) {
                    $candidates += @(Get-ChildItem -LiteralPath $root -Directory -Filter 'jdk-*' -ErrorAction SilentlyContinue |
                        Sort-Object -Property Name -Descending | ForEach-Object { $_.FullName })
                }
            }
            $candidates += 'C:\Program Files\Android\Android Studio\jbr'
            foreach ($candidate in $candidates) {
                if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate 'bin\java.exe'))) { $javaHome = $candidate; break }
            }
            if (-not $javaHome) {
                throw 'nenhum JDK 17+ neste computador. Rode este script de novo na primeira máquina do laboratório, depois do kit.'
            }
            if (-not $toolsZip) { throw 'as Android Command-line Tools não foram baixadas.' }

            $sdkRoot = Join-Path $env:TEMP 'lab-android-sdk'
            $extract = Join-Path $env:TEMP 'lab-android-cli'
            Remove-Item -LiteralPath $sdkRoot, $extract -Recurse -Force -ErrorAction SilentlyContinue
            New-Item -ItemType Directory -Path $extract, (Join-Path $sdkRoot 'cmdline-tools\latest') -Force | Out-Null
            & $tar -xf $toolsZip -C $extract
            Copy-Item -Path (Join-Path $extract 'cmdline-tools\*') -Destination (Join-Path $sdkRoot 'cmdline-tools\latest') -Recurse -Force
            Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue

            $env:JAVA_HOME = $javaHome
            $sdkManager = Join-Path $sdkRoot 'cmdline-tools\latest\bin\sdkmanager.bat'
            $yes = Join-Path $env:TEMP 'lab-android-yes.txt'
            [IO.File]::WriteAllText($yes, (("y`r`n") * 100), [Text.Encoding]::ASCII)
            Write-Host 'Aceitando as licenças do Android SDK...' -ForegroundColor Yellow
            [void](Invoke-Logged -FilePath $sdkManager -ArgumentLine "--sdk_root=`"$sdkRoot`" --licenses" -LogName 'android-licencas' -StandardInputFile $yes)
            Write-Host 'Baixando os componentes do Android SDK (pode demorar)...' -ForegroundColor Cyan
            $packagesLine = "--sdk_root=`"$sdkRoot`" platform-tools `"platforms;android-$AndroidApiLevel`" `"build-tools;$AndroidApiLevel.0.0`" emulator `"extras;google;usb_driver`""
            $code = Invoke-Logged -FilePath $sdkManager -ArgumentLine $packagesLine -LogName 'android-sdk'
            $missing = @($needed | Where-Object { -not (Test-Path -LiteralPath (Join-Path $sdkRoot $_)) })
            if ($missing.Count) { throw "sdkmanager retornou $code; faltam: $($missing -join ', ')" }
        }

        Write-Host 'Compactando o Android SDK...' -ForegroundColor Cyan
        New-Item -ItemType Directory -Path (Split-Path -Path $sdkZip -Parent) -Force | Out-Null
        Remove-Item -LiteralPath "$sdkZip.part" -Force -ErrorAction SilentlyContinue
        $folders = @('platform-tools', 'platforms', 'build-tools', 'emulator', 'extras', 'licenses', 'cmdline-tools') |
            Where-Object { Test-Path -LiteralPath (Join-Path $sdkRoot $_) }
        & $tar -a -c -f "$sdkZip.part" -C $sdkRoot @folders
        if ($LASTEXITCODE -ne 0) { throw "tar.exe retornou $LASTEXITCODE ao compactar." }
        Move-Item -LiteralPath "$sdkZip.part" -Destination $sdkZip -Force
        if ($sdkRoot -ne $installedSdk) { Remove-Item -LiteralPath $sdkRoot -Recurse -Force -ErrorAction SilentlyContinue }
        Add-Line 'Android SDK' 'OK' ([IO.Path]::GetFileName($sdkZip))
    }
    catch {
        Add-Line 'Android SDK' 'MANUAL' $_.Exception.Message
    }
}

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' RESUMO' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
$results | Format-Table -AutoSize -Wrap
$size = (Get-ChildItem -LiteralPath $packageRoot -File -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
Write-Host ("Tamanho atual da pasta Pacotes: {0:N1} GB" -f ($size / 1GB)) -ForegroundColor Cyan
Write-Host 'Itens MANUAL precisam ser colocados em Pacotes antes de levar o kit às máquinas.' -ForegroundColor Yellow
Read-Host 'Pressione Enter para fechar'
