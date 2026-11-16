#Requires -Version 5.1
#Requires -RunAsAdministrator

# Revisão 4 (13/11/2026). Principais mudanças em relação à revisão 3:
#  - WinGet: só é reparado/atualizado quando não funciona ou está abaixo da versão
#    mínima. Antes, toda máquina consultava o GitHub 4 a 5 vezes; com 22 máquinas
#    atrás do mesmo IP o limite de 60 consultas/hora estourava e o kit parava.
#  - Códigos de retorno do WinGet interpretados: "já instalado", "sem atualização"
#    e "reinicialização necessária" deixam de virar FALHA; erros definitivos não
#    são repetidos; erros de rede/instalação em andamento são repetidos com espera.
#  - Cada execução do WinGet tem tempo limite e log próprio (Logs\winget-*.log).
#  - Espera o Windows Update/outro MSI terminar antes de cada instalação (erro 1618).
#  - Visual C++ 2015+ instalado antes (VirtualBox, LibreOffice, XAMPP, PostgreSQL).
#  - PostgreSQL: o --override apagava o "--mode unattended" do manifesto e o
#    arquivo de opções era gravado com BOM; o instalador abria a interface gráfica.
#  - NetBeans: usa o JDK 21 instalado em vez de baixar outro JDK como dependência.
#  - Nmap: o instalador gratuito não aceita modo silencioso (somente o Nmap OEM);
#    agora é aberto no final, com interface, para o técnico clicar em Avançar.
#  - Arduino IDE, Maven e Android SDK sem raspagem de páginas nem API do GitHub.
#  - Downloads em arquivo .part, com nova tentativa; cache corrompido é refeito.
#  - Flutter extraído com tar.exe (muito mais rápido que Expand-Archive) e liberado
#    no Git (safe.directory) para contas padrão.
#  - Instaladores locais (Packet Tracer, MSI, Postman) esperam só o próprio processo,
#    com tempo limite, em vez de Start-Process -Wait (que trava se o app abrir).
#  - Pacotes locais: tudo o que Baixar-Pacotes.ps1 guardou em Pacotes (instaladores,
#    Flutter, Maven, Android SDK...) é usado antes da Internet. Só o que faltar
#    lá é baixado, então as 22 máquinas não repetem gigabytes de download.

[CmdletBinding()]
param(
    [switch]$AcceptPackageAgreements,
    [switch]$AcceptAndroidSdkLicenses,
    [PSCredential]$PostgresCredential,
    [ValidateSet(16, 17, 18)]
    [int]$PostgresMajor = 18,
    [ValidateRange(1, 10)]
    [int]$RetryCount = 3,
    [ValidateRange(30, 37)]
    [int]$AndroidApiLevel = 36,
    [string]$AndroidSdkRoot = 'C:\Android',
    [string]$FlutterRoot = 'C:\Dev\flutter',
    [string]$MinimumWingetVersion = '1.9.0',
    [ValidateRange(10, 240)]
    [int]$PackageTimeoutMinutes = 60,
    [switch]$ForceWingetUpdate,
    [switch]$SkipPostgreSQL,
    [switch]$SkipVisualg,
    [switch]$SkipPacketTracer,
    [switch]$SkipFlutter,
    [switch]$SkipAndroidSdk,
    [switch]$SkipNmap,
    [switch]$SkipInteractiveInstallers
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
try {
    [Console]::InputEncoding = $utf8NoBom
    [Console]::OutputEncoding = $utf8NoBom
}
catch { }
$OutputEncoding = $utf8NoBom

$script:KitRevision = '4 (13/11/2026)'
$script:Results = @()
$script:WingetPath = $null
$script:LastWingetLog = $null
$script:RebootRequired = $false
$script:LogRoot = Join-Path $env:ProgramData 'LabSetup\Logs'
$script:CacheRoot = Join-Path $env:ProgramData 'LabSetup\Cache'
$script:PackageRoot = Join-Path $PSScriptRoot 'Pacotes'

New-Item -ItemType Directory -Path $script:LogRoot -Force | Out-Null
New-Item -ItemType Directory -Path $script:CacheRoot -Force | Out-Null
$runStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$transcriptPath = Join-Path $script:LogRoot "instalacao-$($env:COMPUTERNAME)-$runStamp.log"

# Códigos do WinGet (docs: winget-cli/doc/windows/package-manager/winget/returnCodes.md)
# e alguns códigos do Windows Installer/WinINet que o WinGet repassa.
$script:WingetCodeText = @{
    '-1978335226' = 'o instalador do pacote retornou erro (SHELLEXEC_INSTALL_FAILED)'
    '-1978335224' = 'falha no download do instalador'
    '-1978335216' = 'o manifesto não tem instalador para o escopo/arquitetura pedidos'
    '-1978335215' = 'o hash do instalador não confere com o manifesto (catálogo desatualizado)'
    '-1978335212' = 'pacote não encontrado no catálogo winget'
    '-1978335189' = 'já instalado; nenhuma atualização disponível'
    '-1978335135' = 'pacote já instalado'
    '-1978334975' = 'o programa está em uso'
    '-1978334974' = 'outra instalação está em andamento'
    '-1978334973' = 'arquivo em uso'
    '-1978334972' = 'falta uma dependência'
    '-1978334971' = 'disco cheio'
    '-1978334970' = 'memória insuficiente'
    '-1978334969' = 'sem conexão de rede'
    '-1978334968' = 'o instalador pediu contato com o suporte do fabricante'
    '-1978334967' = 'instalado; reinicialização necessária para concluir'
    '-1978334966' = 'o Windows precisa ser reiniciado ANTES desta instalação'
    '-1978334965' = 'o instalador iniciou uma reinicialização'
    '-1978334964' = 'instalação cancelada'
    '-1978334963' = 'já instalado (informado pelo instalador)'
    '-1978334962' = 'uma versão mais nova já está instalada'
    '-1978334961' = 'bloqueado por política'
    '-1978334960' = 'falha ao instalar as dependências do pacote'
    '-1978334959' = 'o programa está aberto e impede a instalação'
    '-2147023278' = 'outra instalação MSI (Windows Update) está em andamento (1618)'
    '-2147012894' = 'tempo de conexão esgotado'
    '-2147012889' = 'nome do servidor não resolvido (DNS)'
    '-2147012867' = 'não foi possível conectar ao servidor'
    '-2147012721' = 'erro de conexão segura (data/hora, proxy ou inspeção TLS)'
    '1618'        = 'outra instalação MSI (Windows Update) está em andamento'
    '1603'        = 'erro fatal do Windows Installer'
    '-2'          = 'tempo limite esgotado; o processo foi encerrado'
}

function Add-Result {
    param(
        [Parameter(Mandatory = $true)][string]$Component,
        [Parameter(Mandatory = $true)][ValidateSet('OK', 'FALHA', 'PENDENTE', 'IGNORADO', 'AVISO')][string]$Status,
        [Parameter(Mandatory = $true)][string]$Details
    )

    $script:Results += [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        Component    = $Component
        Status       = $Status
        Details      = $Details
        Timestamp    = (Get-Date).ToString('s')
    }

    $color = switch ($Status) {
        'OK'       { 'Green' }
        'FALHA'    { 'Red' }
        'PENDENTE' { 'Yellow' }
        'AVISO'    { 'Yellow' }
        default    { 'DarkGray' }
    }
    Write-Host ("[{0}] {1}: {2}" -f $Status, $Component, $Details) -ForegroundColor $color
}

function Invoke-LabStep {
    param(
        [Parameter(Mandatory = $true)][string]$Component,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    Write-Host ''
    Write-Host ("=== {0} ===" -f $Component) -ForegroundColor Cyan
    try {
        & $Action
    }
    catch {
        $line = $_.InvocationInfo.ScriptLineNumber
        Add-Result -Component $Component -Status 'FALHA' -Details ("{0} (linha {1})" -f $_.Exception.Message, $line)
    }
}

function Test-IsInteractive {
    try {
        return [Environment]::UserInteractive -and $Host.Name -notmatch 'ServerRemoteHost'
    }
    catch {
        return $false
    }
}

function Confirm-Agreements {
    if ($AcceptPackageAgreements) {
        return
    }

    if (-not (Test-IsInteractive)) {
        throw 'A execução remota exige -AcceptPackageAgreements. Leia o README antes de aceitar licenças de terceiros.'
    }

    Write-Host ''
    Write-Host 'Este procedimento instalará pacotes de terceiros e aceitará os termos apresentados pelo WinGet.' -ForegroundColor Yellow
    $answer = Read-Host 'Depois de revisar as licenças da sua instituição, digite ACEITO para continuar'
    if ($answer -cne 'ACEITO') {
        throw 'Instalação cancelada: os termos não foram aceitos.'
    }
}

function Format-ExitCode {
    param([int]$Code)

    $hex = '0x{0:X8}' -f $Code
    $key = [string]$Code
    if ($script:WingetCodeText.ContainsKey($key)) {
        return "código $Code ($hex): $($script:WingetCodeText[$key])"
    }
    return "código $Code ($hex)"
}

# ---------------------------------------------------------------------------
# Execução de processos
# ---------------------------------------------------------------------------

function ConvertTo-CommandLineArgument {
    param([AllowEmptyString()][string]$Value)

    if ($Value -eq '') { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }
    # Regras de CommandLineToArgvW: barras antes de aspas são duplicadas.
    $escaped = [Regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [Regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Read-NewLogText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][ref]$Position
    )

    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $stream = $null
    try {
        $stream = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        if ($stream.Length -le $Position.Value) { return '' }
        [void]$stream.Seek($Position.Value, [System.IO.SeekOrigin]::Begin)
        $buffer = New-Object byte[] ([int]($stream.Length - $Position.Value))
        $read = $stream.Read($buffer, 0, $buffer.Length)
        $Position.Value += $read
        return [System.Text.Encoding]::UTF8.GetString($buffer, 0, $read)
    }
    catch {
        return ''
    }
    finally {
        if ($stream) { $stream.Dispose() }
    }
}

function Write-ProcessLines {
    param([AllowEmptyString()][string]$Text)

    foreach ($rawLine in ($Text -split "[`r`n]+")) {
        $line = $rawLine.Trim()
        # Barras de progresso e spinners do WinGet/sdkmanager poluem a tela.
        if (-not $line) { continue }
        if ($line -notmatch '[A-Za-zÀ-ú]{2}') { continue }
        if ($line -match '[█▒]' -or $line -match '^\[=*\s*\]') { continue }
        if ($line.Length -gt 220) { $line = $line.Substring(0, 220) + '...' }
        Write-Host "      $line"
    }
}

function Invoke-LoggedProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory = $true)][string]$LogName,
        [int]$TimeoutMinutes = 60,
        [string]$StandardInputFile,
        [switch]$Quiet
    )

    # Start-Process -Wait espera também os processos filhos; se o instalador
    # abrir o próprio aplicativo ao terminar, o script ficaria parado. Aqui se
    # espera só o processo iniciado, com tempo limite, e a saída vai para log.
    $safeName = ($LogName -replace '[^A-Za-z0-9._-]', '_')
    $stamp = Get-Date -Format 'HHmmss-fff'
    $outFile = Join-Path $script:LogRoot "$safeName-$runStamp-$stamp.log"
    $errFile = Join-Path $script:LogRoot "$safeName-$runStamp-$stamp.err.log"
    $argumentLine = (@($Arguments | Where-Object { $null -ne $_ }) |
        ForEach-Object { ConvertTo-CommandLineArgument -Value $_ }) -join ' '

    $startParameters = @{
        FilePath               = $FilePath
        NoNewWindow            = $true
        PassThru               = $true
        RedirectStandardOutput = $outFile
        RedirectStandardError  = $errFile
    }
    if ($argumentLine) { $startParameters['ArgumentList'] = $argumentLine }
    if ($StandardInputFile) { $startParameters['RedirectStandardInput'] = $StandardInputFile }

    $exitCode = -1
    $timedOut = $false
    $process = $null
    try {
        $process = Start-Process @startParameters
        $null = $process.Handle   # necessário para ler ExitCode depois no PS 5.1
        $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
        $outPosition = [long]0
        $errPosition = [long]0
        while (-not $process.WaitForExit(2000)) {
            if (-not $Quiet) {
                Write-ProcessLines -Text (Read-NewLogText -Path $outFile -Position ([ref]$outPosition))
                Write-ProcessLines -Text (Read-NewLogText -Path $errFile -Position ([ref]$errPosition))
            }
            if ((Get-Date) -gt $deadline) {
                $timedOut = $true
                Write-Warning "Tempo limite de $TimeoutMinutes min atingido; encerrando $([IO.Path]::GetFileName($FilePath))."
                [void](Invoke-NativeCommand -FilePath 'taskkill.exe' -Arguments @('/PID', [string]$process.Id, '/T', '/F'))
                [void]$process.WaitForExit(30000)
                break
            }
        }
        $process.WaitForExit()
        if (-not $Quiet) {
            Write-ProcessLines -Text (Read-NewLogText -Path $outFile -Position ([ref]$outPosition))
            Write-ProcessLines -Text (Read-NewLogText -Path $errFile -Position ([ref]$errPosition))
        }
        $exitCode = if ($timedOut) { -2 } else { [int]$process.ExitCode }
    }
    catch {
        Write-Warning "Não foi possível executar ${FilePath}: $($_.Exception.Message)"
        Add-Content -LiteralPath $errFile -Value $_.Exception.Message -ErrorAction SilentlyContinue
        $exitCode = -1
    }
    finally {
        if ($process) { $process.Dispose() }
    }

    $lines = @()
    foreach ($file in @($outFile, $errFile)) {
        if (Test-Path -LiteralPath $file) {
            $lines += @(Get-Content -LiteralPath $file -Encoding UTF8 -ErrorAction SilentlyContinue)
        }
    }
    if ((Test-Path -LiteralPath $errFile) -and ((Get-Item -LiteralPath $errFile).Length -eq 0)) {
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }

    return [PSCustomObject]@{
        ExitCode = $exitCode
        TimedOut = $timedOut
        Output   = [string[]]$lines
        LogFile  = $outFile
    }
}

# Usado só para comandos curtos (versões, git config, icacls).
function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    $lines = New-Object 'System.Collections.Generic.List[string]'
    $previousPreference = $ErrorActionPreference
    $exitCode = -1
    try {
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = -1
        & $FilePath @Arguments 2>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                [void]$lines.Add([string]$_.Exception.Message)
            }
            else {
                [void]$lines.Add([string]$_)
            }
        }
        $exitCode = [int]$LASTEXITCODE
    }
    catch {
        [void]$lines.Add($_.Exception.Message)
        $exitCode = -1
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    return [PSCustomObject]@{
        ExitCode = $exitCode
        Output   = [string[]]$lines.ToArray()
    }
}

function Wait-InstallerIdle {
    param([int]$MaxMinutes = 30)

    # O mutex Global\_MSIExecute existe enquanto qualquer instalação MSI roda
    # (inclusive Windows Update). Instalar nesse momento termina com erro 1618.
    $deadline = (Get-Date).AddMinutes($MaxMinutes)
    $warned = $false
    while ((Get-Date) -lt $deadline) {
        $busy = $false
        $mutex = $null
        try {
            if ([System.Threading.Mutex]::TryOpenExisting('Global\_MSIExecute', [ref]$mutex)) {
                $busy = $true
            }
        }
        catch [System.UnauthorizedAccessException] {
            $busy = $true
        }
        catch { }
        finally {
            if ($mutex) { $mutex.Dispose() }
        }

        if (-not $busy) { return $true }
        if (-not $warned) {
            Write-Host '    Aguardando outra instalação do Windows (Windows Update/MSI) terminar...' -ForegroundColor DarkYellow
            $warned = $true
        }
        Start-Sleep -Seconds 15
    }
    Write-Warning "Outra instalação continua em andamento após $MaxMinutes minutos; tentando mesmo assim."
    return $false
}

function Test-PendingReboot {
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    foreach ($key in $keys) {
        if (Test-Path -LiteralPath $key) { return $true }
    }
    return $false
}

# ---------------------------------------------------------------------------
# Ambiente, PATH e permissões
# ---------------------------------------------------------------------------

function Update-ProcessEnvironment {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (($machinePath, $userPath) -join ';').Trim(';')

    foreach ($name in 'JAVA_HOME', 'ANDROID_HOME', 'ANDROID_SDK_ROOT', 'MAVEN_HOME') {
        $value = [Environment]::GetEnvironmentVariable($name, 'Machine')
        if ($value) {
            Set-Item -Path "Env:$name" -Value $value
        }
    }
}

function Add-MachinePath {
    param([Parameter(Mandatory = $true)][string]$PathToAdd)

    $normalized = $PathToAdd.TrimEnd('\')
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $entries = @($machinePath -split ';' | Where-Object { $_ })
    $normalizedEntries = @($entries | ForEach-Object { $_.Trim().TrimEnd('\') })
    if ($normalizedEntries -notcontains $normalized) {
        $newPath = (($entries + $normalized) -join ';')
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'Machine')
    }
    Update-ProcessEnvironment
}

function Grant-LabUsersModify {
    param([Parameter(Mandatory = $true)][string]$TargetPath)

    if (-not (Test-Path -LiteralPath $TargetPath)) {
        return $false
    }

    # S-1-5-32-545 é o grupo interno Users, independente do idioma do Windows.
    # (OI)(CI) é herdado por tudo o que já existe e pelo que for criado depois;
    # /T (aplicar arquivo por arquivo) era lento no Flutter/Android SDK.
    $result = Invoke-NativeCommand -FilePath 'icacls.exe' `
        -Arguments @($TargetPath, '/grant', '*S-1-5-32-545:(OI)(CI)M', '/C', '/Q')
    return ($result.ExitCode -eq 0)
}

function Get-MachineInstalledDisplayNames {
    # Lê as visões de 64 e 32 bits pelo .NET; entradas inválidas são ignoradas.
    $displayNames = New-Object 'System.Collections.Generic.List[string]'
    $views = @(
        [Microsoft.Win32.RegistryView]::Registry64,
        [Microsoft.Win32.RegistryView]::Registry32
    )

    foreach ($view in $views) {
        $baseKey = $null
        $uninstallKey = $null
        try {
            $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
                [Microsoft.Win32.RegistryHive]::LocalMachine,
                $view
            )
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

function Test-MachineDisplayName {
    param([Parameter(Mandatory = $true)][string]$Pattern)
    return [bool](@(Get-MachineInstalledDisplayNames | Where-Object { $_ -like $Pattern }).Count)
}

function Test-AnyPath {
    param([string[]]$Patterns)
    foreach ($pattern in @($Patterns)) {
        if ($pattern -and (Test-Path -Path $pattern)) { return $true }
    }
    return $false
}

# ---------------------------------------------------------------------------
# Downloads e assinaturas
# ---------------------------------------------------------------------------

function Test-FileHashValue {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedHash,
        [Parameter(Mandatory = $true)][string]$Algorithm
    )
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash
    return ($actual -ieq $ExpectedHash.Trim())
}

function Save-RemoteFile {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$Destination,
        [string]$ExpectedHash,
        [ValidateSet('SHA1', 'SHA256', 'SHA512')][string]$Algorithm = 'SHA256',
        [string[]]$MirrorUris = @(),
        [int]$Attempts = 3
    )

    if (Test-Path -LiteralPath $Destination) {
        if (-not $ExpectedHash -or (Test-FileHashValue -Path $Destination -ExpectedHash $ExpectedHash -Algorithm $Algorithm)) {
            return
        }
        Write-Warning "O arquivo em cache $Destination está corrompido; baixando novamente."
        Remove-Item -LiteralPath $Destination -Force
    }

    # Baixa para .part e só renomeia quando completo e conferido. Na revisão 3,
    # um download interrompido ficava no cache e falhava em todas as execuções.
    $partial = "$Destination.part"
    $lastError = $null
    $sources = @($Uri) + @($MirrorUris | Where-Object { $_ })
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        foreach ($source in $sources) {
            Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
            try {
                Write-Host "    Baixando $source" -ForegroundColor DarkGray
                $downloaded = $false
                if (Get-Command 'Start-BitsTransfer' -ErrorAction SilentlyContinue) {
                    try {
                        Start-BitsTransfer -Source $source -Destination $partial -DisplayName 'Preparação do laboratório' -ErrorAction Stop
                        $downloaded = $true
                    }
                    catch {
                        Write-Host "    BITS falhou ($($_.Exception.Message)); tentando Invoke-WebRequest." -ForegroundColor DarkYellow
                        Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
                    }
                }
                if (-not $downloaded) {
                    Invoke-WebRequest -UseBasicParsing -Uri $source -OutFile $partial -TimeoutSec 600 -ErrorAction Stop
                }
                if (-not (Test-Path -LiteralPath $partial) -or (Get-Item -LiteralPath $partial).Length -eq 0) {
                    throw 'o arquivo baixado está vazio.'
                }
                if ($ExpectedHash -and -not (Test-FileHashValue -Path $partial -ExpectedHash $ExpectedHash -Algorithm $Algorithm)) {
                    throw "o hash $Algorithm do arquivo baixado não confere."
                }
                Move-Item -LiteralPath $partial -Destination $Destination -Force
                return
            }
            catch {
                $lastError = $_.Exception.Message
                Write-Warning "Download falhou (tentativa $attempt/$Attempts): $lastError"
            }
        }
        if ($attempt -lt $Attempts) { Start-Sleep -Seconds (10 * $attempt) }
    }
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    throw "Falha ao baixar $Uri após $Attempts tentativas: $lastError"
}

function Get-RemoteText {
    param([Parameter(Mandatory = $true)][string]$Uri)

    $response = Invoke-WebRequest -UseBasicParsing -Uri $Uri -TimeoutSec 120 -ErrorAction Stop
    $content = $response.Content
    if ($content -is [byte[]]) { $content = [Text.Encoding]::UTF8.GetString($content) }
    return ([string]$content).TrimStart([char]0xFEFF)
}

function Test-TrustedPublisherSignature {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$PublisherPattern
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    return ($signature.Status -eq 'Valid' -and
        $signature.SignerCertificate -and
        $signature.SignerCertificate.Subject -match $PublisherPattern)
}

function Expand-ArchiveFast {
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    $sevenZip = @(
        (Join-Path $env:ProgramFiles '7-Zip\7z.exe'),
        (Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if ($sevenZip) {
        $result = Invoke-LoggedProcess -FilePath $sevenZip -Arguments @('x', $ArchivePath, "-o$Destination", '-y', '-bso0', '-bsp0') `
            -LogName 'extrair-7zip' -Quiet -TimeoutMinutes 60
        if ($result.ExitCode -eq 0) { return }
        Write-Warning "7-Zip retornou $($result.ExitCode) ao extrair $ArchivePath."
    }

    # tar.exe (libarchive) acompanha o Windows 11 e extrai ZIP muito mais rápido
    # que Expand-Archive do PowerShell 5.1.
    $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (Test-Path -LiteralPath $tar) {
        $result = Invoke-LoggedProcess -FilePath $tar -Arguments @('-xf', $ArchivePath, '-C', $Destination) `
            -LogName 'extrair-tar' -Quiet -TimeoutMinutes 60
        if ($result.ExitCode -eq 0) { return }
        Write-Warning "tar.exe retornou $($result.ExitCode) ao extrair $ArchivePath."
    }

    if ($ArchivePath -match '\.zip$') {
        Expand-Archive -LiteralPath $ArchivePath -DestinationPath $Destination -Force
        return
    }
    throw "Não foi possível extrair $ArchivePath (7-Zip e tar.exe falharam)."
}

# ---------------------------------------------------------------------------
# WinGet
# ---------------------------------------------------------------------------

function Get-WingetVersionFromPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $probe = Invoke-NativeCommand -FilePath $Path -Arguments @('--version')
    if ($probe.ExitCode -ne 0) { return $null }
    foreach ($line in $probe.Output) {
        $match = [Regex]::Match([string]$line, '[0-9]+(?:\.[0-9]+){1,3}')
        if ($match.Success) { return [Version]$match.Value }
    }
    return $null
}

function Get-WingetExecutable {
    $candidates = New-Object 'System.Collections.Generic.List[string]'
    try {
        $packages = @(Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -AllUsers -ErrorAction SilentlyContinue |
            Sort-Object -Property Version -Descending)
        foreach ($package in $packages) {
            if ($package.InstallLocation) {
                [void]$candidates.Add((Join-Path $package.InstallLocation 'winget.exe'))
            }
        }
    }
    catch { }

    $command = Get-Command 'winget.exe' -ErrorAction SilentlyContinue
    if ($command -and $command.Source) {
        [void]$candidates.Add($command.Source)
    }
    [void]$candidates.Add((Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'))

    foreach ($candidate in @($candidates | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $candidate)) { continue }
        if (Get-WingetVersionFromPath -Path $candidate) {
            return $candidate
        }
    }
    return $null
}

function Repair-WingetWithModule {
    Write-Host 'Reparando o App Installer/WinGet pelo módulo Microsoft.WinGet.Client...' -ForegroundColor Cyan
    if (-not (Get-PackageProvider -ListAvailable -Name 'NuGet' -ErrorAction SilentlyContinue |
            Where-Object { $_.Version -ge [Version]'2.8.5.201' })) {
        Install-PackageProvider -Name 'NuGet' -MinimumVersion '2.8.5.201' -Force -Scope AllUsers -ErrorAction Stop | Out-Null
    }

    if (-not (Get-Module -ListAvailable -Name 'Microsoft.WinGet.Client')) {
        $gallery = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
        if (-not $gallery) {
            Register-PSRepository -Default -ErrorAction Stop
            $gallery = Get-PSRepository -Name 'PSGallery' -ErrorAction Stop
        }
        $previousGalleryPolicy = [string]$gallery.InstallationPolicy
        try {
            if ($previousGalleryPolicy -ne 'Trusted') {
                Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction Stop
            }
            Install-Module -Name 'Microsoft.WinGet.Client' -Repository 'PSGallery' -Scope AllUsers `
                -Force -AllowClobber -Confirm:$false -ErrorAction Stop | Out-Null
        }
        finally {
            if ($previousGalleryPolicy -and $previousGalleryPolicy -ne 'Trusted') {
                Set-PSRepository -Name 'PSGallery' -InstallationPolicy $previousGalleryPolicy -ErrorAction SilentlyContinue
            }
        }
    }
    Import-Module 'Microsoft.WinGet.Client' -Force -ErrorAction Stop
    Repair-WinGetPackageManager -AllUsers -Force -Latest -ErrorAction Stop |
        ForEach-Object { if ($null -ne $_) { Write-Host "      $_" } }
}

function Install-WingetFromBundle {
    Write-Host 'Instalando o App Installer diretamente do pacote oficial da Microsoft...' -ForegroundColor Cyan
    $bundle = Join-Path $script:CacheRoot 'Microsoft.DesktopAppInstaller.msixbundle'
    Remove-Item -LiteralPath $bundle -Force -ErrorAction SilentlyContinue
    Save-RemoteFile -Uri 'https://aka.ms/getwinget' -Destination $bundle
    if (-not (Test-TrustedPublisherSignature -Path $bundle -PublisherPattern 'Microsoft')) {
        throw 'O pacote do App Installer baixado não tem assinatura válida da Microsoft.'
    }
    try {
        Add-AppxProvisionedPackage -Online -PackagePath $bundle -SkipLicense -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Warning "Provisionamento para novos perfis falhou: $($_.Exception.Message)"
    }
    Add-AppxPackage -Path $bundle -ForceApplicationShutdown -ErrorAction Stop
}

function Register-AppInstallerForCurrentUser {
    $addAppx = Get-Command 'Add-AppxPackage' -ErrorAction SilentlyContinue
    if ($addAppx -and $addAppx.Parameters.ContainsKey('RegisterByFamilyName')) {
        try {
            Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop
        }
        catch {
            Write-Host "    Registro do App Installer: $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
    }
}

function Invoke-Winget {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [string]$LogName = 'winget',
        [int]$TimeoutMinutes = 15
    )

    $wingetLog = Join-Path $script:LogRoot ("{0}-{1}-{2}.winget.log" -f ($LogName -replace '[^A-Za-z0-9._-]', '_'), $runStamp, (Get-Date -Format 'HHmmss'))
    $fullArguments = @($Arguments)
    if ($Arguments[0] -in @('install', 'download', 'upgrade')) {
        $fullArguments += @('--log', $wingetLog)
        $script:LastWingetLog = $wingetLog
    }
    $display = @()
    $hideNext = $false
    foreach ($argument in $Arguments) {
        if ($hideNext) { $display += '<oculto>'; $hideNext = $false; continue }
        if ($argument -eq '--override') { $hideNext = $true }
        $display += $argument
    }
    Write-Host ("    winget {0}" -f ($display -join ' ')) -ForegroundColor DarkGray
    $result = Invoke-LoggedProcess -FilePath $script:WingetPath -Arguments $fullArguments `
        -LogName "winget-$LogName" -TimeoutMinutes $TimeoutMinutes
    return [int]$result.ExitCode
}

function Update-WingetSource {
    Write-Host 'Atualizando o catálogo oficial da fonte winget...' -ForegroundColor Cyan
    $code = Invoke-Winget -Arguments @('source', 'update', '--name', 'winget', '--disable-interactivity') -LogName 'source-update'
    if ($code -ne 0) {
        Write-Warning "A atualização da fonte falhou ($(Format-ExitCode $code)). Redefinindo somente a fonte winget."
        [void](Invoke-Winget -Arguments @('source', 'reset', '--name', 'winget', '--force', '--disable-interactivity') -LogName 'source-reset')
        $code = Invoke-Winget -Arguments @('source', 'update', '--name', 'winget', '--disable-interactivity') -LogName 'source-update'
    }
    return $code
}

function Initialize-Winget {
    $minimum = [Version]$MinimumWingetVersion
    Register-AppInstallerForCurrentUser
    $script:WingetPath = Get-WingetExecutable
    $current = if ($script:WingetPath) { Get-WingetVersionFromPath -Path $script:WingetPath } else { $null }
    $action = 'já funcionava'

    if ($current -and $current -ge $minimum -and -not $ForceWingetUpdate) {
        Write-Host "WinGet $current funcionando (mínimo $minimum); atualização dispensada." -ForegroundColor DarkGray
    }
    else {
        $reason = if ($current) { "versão $current abaixo da mínima $minimum" } else { 'winget.exe não inicia' }
        if ($ForceWingetUpdate) { $reason = 'atualização forçada' }
        Write-Host "WinGet precisa de reparo: $reason." -ForegroundColor Yellow
        try {
            Repair-WingetWithModule
            $action = 'reparado pelo módulo Microsoft.WinGet.Client'
        }
        catch {
            Write-Warning "O reparo pelo módulo falhou: $($_.Exception.Message)"
        }
        Update-ProcessEnvironment
        Register-AppInstallerForCurrentUser
        $script:WingetPath = Get-WingetExecutable
        $current = if ($script:WingetPath) { Get-WingetVersionFromPath -Path $script:WingetPath } else { $null }

        if (-not $current -or $current -lt $minimum) {
            try {
                Install-WingetFromBundle
                $action = 'instalado pelo pacote oficial aka.ms/getwinget'
            }
            catch {
                Write-Warning "A instalação pelo pacote oficial falhou: $($_.Exception.Message)"
            }
            Register-AppInstallerForCurrentUser
            $script:WingetPath = Get-WingetExecutable
            $current = if ($script:WingetPath) { Get-WingetVersionFromPath -Path $script:WingetPath } else { $null }
        }
    }

    if (-not $script:WingetPath -or -not $current) {
        throw 'winget.exe não inicia nem depois do reparo. Reinicie o Windows, instale as atualizações pendentes e execute o kit novamente.'
    }
    if ($current -lt $minimum) {
        Add-Result -Component 'WinGet' -Status 'AVISO' -Details "Versão $current abaixo da mínima $minimum; o kit tentará continuar."
    }

    $sourceCode = Update-WingetSource
    if ($sourceCode -ne 0) {
        throw "O WinGet funciona, mas a fonte winget não pôde ser atualizada ($(Format-ExitCode $sourceCode)). Verifique Internet, proxy e data/hora."
    }

    Add-Result -Component 'WinGet' -Status 'OK' -Details "WinGet $current ($action); fonte winget atualizada."
}

function Find-PackageFile {
    param(
        [Parameter(Mandatory = $true)][string[]]$Filters,
        [string]$SubFolder
    )

    # Procura em Pacotes (com subpastas) o que Baixar-Pacotes.ps1 guardou ou o
    # que foi colocado à mão. Dependências baixadas junto pelo WinGet ficam de
    # fora para não instalar o Visual C++ no lugar do VirtualBox, por exemplo.
    $searches = @()
    if ($SubFolder) {
        $searches += @{ Path = (Join-Path $script:PackageRoot $SubFolder); Recurse = $true }
    }
    else {
        $searches += @{ Path = $script:PackageRoot; Recurse = $true }
        $searches += @{ Path = $PSScriptRoot; Recurse = $false }
    }
    foreach ($filter in $Filters) {
        $found = foreach ($search in $searches) {
            if (Test-Path -LiteralPath $search.Path) {
                Get-ChildItem -LiteralPath $search.Path -Filter $filter -File -Recurse:$search.Recurse -ErrorAction SilentlyContinue
            }
        }
        $file = @($found) |
            Where-Object { $_ -and $_.Name -notmatch '\.(part|yaml|yml)$' -and $_.FullName -notmatch '\\Dependencies\\' -and $_.Length -gt 0 } |
            Sort-Object -Property LastWriteTime -Descending |
            Select-Object -First 1
        if ($file) { return $file }
    }
    return $null
}

function Copy-ToLocalCache {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo]$File)

    # Instalar direto do pendrive é lento e falha se ele for removido no meio.
    $target = Join-Path $script:CacheRoot $File.Name
    if (-not (Test-Path -LiteralPath $target) -or (Get-Item -LiteralPath $target).Length -ne $File.Length) {
        Write-Host "    Copiando $($File.Name) de Pacotes para o disco local..." -ForegroundColor DarkGray
        Copy-Item -LiteralPath $File.FullName -Destination $target -Force
    }
    Unblock-File -LiteralPath $target -ErrorAction SilentlyContinue
    return $target
}

function Install-FromLocalFile {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$File,
        [string[]]$ExeArguments = @(),
        [string[]]$MsiProperties = @(),
        [string]$ZipDestination,
        [int]$TimeoutMinutes = $PackageTimeoutMinutes
    )

    $safeName = ($Name -replace '[^A-Za-z0-9]', '_')
    $extension = $File.Extension.ToLowerInvariant()
    if ($extension -eq '.zip') {
        if (-not $ZipDestination) { throw "Não há pasta de destino definida para $($File.Name)." }
        Expand-ArchiveFast -ArchivePath $File.FullName -Destination $ZipDestination
        return 0
    }

    $localPath = Copy-ToLocalCache -File $File
    [void](Wait-InstallerIdle)
    if ($extension -eq '.msi') {
        $msiLog = Join-Path $script:LogRoot "$safeName-msi-$runStamp.log"
        $arguments = @('/i', $localPath, '/qn', '/norestart', 'ALLUSERS=1') + @($MsiProperties) + @('/l*v', $msiLog)
        $result = Invoke-LoggedProcess -FilePath 'msiexec.exe' -Arguments $arguments `
            -LogName "$safeName-local" -TimeoutMinutes $TimeoutMinutes -Quiet
    }
    else {
        $result = Invoke-LoggedProcess -FilePath $localPath -Arguments $ExeArguments `
            -LogName "$safeName-local" -TimeoutMinutes $TimeoutMinutes -Quiet
    }
    if ($result.ExitCode -in @(3010, 1641)) { $script:RebootRequired = $true }
    return [int]$result.ExitCode
}

$script:WingetOutcomes = @{
    '0'           = 'Success'
    '-1978335189' = 'Success'        # sem atualização: já instalado
    '-1978335135' = 'Success'        # pacote já instalado
    '-1978334963' = 'Success'        # instalador: já instalado
    '-1978334967' = 'SuccessReboot'  # 3010: reinicialização para concluir
    '-1978334965' = 'SuccessReboot'
    '-1978335216' = 'NoApplicable'
    '-1978335212' = 'Fatal'
    '-1978334971' = 'Fatal'
    '-1978334961' = 'Fatal'
    '-1978334962' = 'Fatal'
    '-1978334966' = 'RebootFirst'
    '-1978335215' = 'HashMismatch'
    '-2'          = 'Timeout'
}

function Get-WingetOutcome {
    param([int]$Code)

    $key = [string]$Code
    if ($script:WingetOutcomes.ContainsKey($key)) {
        return $script:WingetOutcomes[$key]
    }
    return 'Retry'
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$CandidateIds,
        [ValidateSet('machine', 'user', 'auto')][string]$Scope = 'machine',
        [string]$Override,
        [string]$Custom,
        [string]$Location,
        [string]$InstallerType,
        [string]$MachineDisplayNamePattern,
        [string[]]$MachineVerificationPaths,
        [switch]$AllowVerifiedUnknownScopeFallback,
        [switch]$SkipDependencies,
        [switch]$Optional,
        [int]$TimeoutMinutes = $PackageTimeoutMinutes,
        [string]$LocalFolder,
        [string[]]$LocalArguments = @(),
        [string[]]$LocalMsiProperties = @(),
        [string]$LocalZipDestination
    )

    $hasMachineEvidence = [bool]($MachineDisplayNamePattern -or $MachineVerificationPaths)
    $testMachineEvidence = {
        if ($MachineDisplayNamePattern -and (Test-MachineDisplayName -Pattern $MachineDisplayNamePattern)) {
            return $true
        }
        return (Test-AnyPath -Patterns $MachineVerificationPaths)
    }

    if ($hasMachineEvidence -and (& $testMachineEvidence)) {
        Add-Result -Component $Name -Status 'OK' -Details 'Já instalado no escopo da máquina.'
        return $true
    }

    # Pacote local (Pacotes\WinGet\<Id>) primeiro; a Internet só se ele faltar ou falhar.
    $localFolderName = if ($LocalFolder) { $LocalFolder } else { $CandidateIds[0] }
    $localFile = Find-PackageFile -Filters @('*.msi', '*.exe', '*.zip') -SubFolder "WinGet\$localFolderName"
    if ($localFile -and $hasMachineEvidence) {
        Write-Host "Instalando $Name a partir de Pacotes ($($localFile.Name))..." -ForegroundColor Cyan
        try {
            $localCode = Install-FromLocalFile -Name $Name -File $localFile -ExeArguments $LocalArguments `
                -MsiProperties $LocalMsiProperties -ZipDestination $LocalZipDestination -TimeoutMinutes $TimeoutMinutes
            if (& $testMachineEvidence) {
                Add-Result -Component $Name -Status 'OK' -Details "Pacote local: $($localFile.Name)"
                return $true
            }
            Write-Warning "O pacote local $($localFile.Name) terminou com $(Format-ExitCode $localCode), mas a instalação não foi confirmada. Tentando pelo WinGet."
        }
        catch {
            Write-Warning "Falha com o pacote local $($localFile.Name): $($_.Exception.Message). Tentando pelo WinGet."
        }
    }
    elseif (-not $localFile) {
        Write-Host "    $Name não está em Pacotes; será baixado pela Internet." -ForegroundColor DarkGray
    }

    $lastProblem = 'nenhuma tentativa foi feita'
    $needsRebootFirst = $false
    foreach ($id in $CandidateIds) {
        # Primeiro o escopo pedido. Se o manifesto não declarar escopo (NetBeans,
        # Eclipse...), o WinGet responde "sem instalador aplicável" na hora; então
        # tenta sem --scope e confirma pelos caminhos da máquina.
        $scopes = @()
        if ($Scope -eq 'auto') {
            $scopes += ''
        }
        else {
            $scopes += $Scope
            if ($Scope -eq 'machine' -and $AllowVerifiedUnknownScopeFallback -and $hasMachineEvidence) {
                $scopes += ''
            }
        }

        foreach ($currentScope in $scopes) {
            $arguments = @(
                'install', '--id', $id, '--exact', '--source', 'winget',
                '--silent', '--disable-interactivity',
                '--accept-source-agreements', '--accept-package-agreements'
            )
            if ($currentScope) { $arguments += @('--scope', $currentScope) }
            if ($Override) { $arguments += @('--override', $Override) }
            if ($Custom) { $arguments += @('--custom', $Custom) }
            if ($Location) { $arguments += @('--location', $Location) }
            if ($InstallerType) { $arguments += @('--installer-type', $InstallerType) }
            if ($SkipDependencies) { $arguments += '--skip-dependencies' }

            $sourceRefreshed = $false
            $scopeLabel = if ($currentScope) { $currentScope } else { 'padrão do manifesto' }
            for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
                [void](Wait-InstallerIdle)
                Write-Host ("Instalando {0} (pacote {1}, escopo {2}, tentativa {3}/{4})..." -f $Name, $id, $scopeLabel, $attempt, $RetryCount) -ForegroundColor Cyan
                $code = Invoke-Winget -Arguments $arguments -LogName $id -TimeoutMinutes $TimeoutMinutes
                $outcome = Get-WingetOutcome -Code $code
                $evidenceOk = (-not $hasMachineEvidence) -or (& $testMachineEvidence)

                if ($outcome -eq 'SuccessReboot') { $script:RebootRequired = $true }
                if ($outcome -in @('Success', 'SuccessReboot')) {
                    if ($evidenceOk) {
                        $note = if ($code -ne 0) { " ($(Format-ExitCode $code))" } else { '' }
                        Add-Result -Component $Name -Status 'OK' -Details "WinGet: $id$note"
                        return $true
                    }
                    $lastProblem = "$id terminou sem erro, mas não foi encontrado nos caminhos da máquina"
                    Write-Warning $lastProblem
                    break
                }

                # Instaladores às vezes retornam erro mesmo tendo instalado
                # (ex.: dependência Visual C++ já mais nova). Confere o resultado real.
                if ($hasMachineEvidence -and (& $testMachineEvidence)) {
                    Add-Result -Component $Name -Status 'OK' -Details "WinGet: $id instalado, apesar do $(Format-ExitCode $code)."
                    return $true
                }

                $lastProblem = "${id}: $(Format-ExitCode $code)"
                Write-Warning $lastProblem
                if ($outcome -in @('NoApplicable', 'Fatal')) { break }
                if ($outcome -eq 'RebootFirst') { $needsRebootFirst = $true; break }
                if ($outcome -eq 'HashMismatch' -and -not $sourceRefreshed) {
                    [void](Update-WingetSource)
                    $sourceRefreshed = $true
                }
                if ($attempt -lt $RetryCount) {
                    Start-Sleep -Seconds (20 * $attempt)
                }
            }
            if ($needsRebootFirst) { break }
        }
        if ($needsRebootFirst) { break }
    }

    $logHint = if ($script:LastWingetLog) { " Log: $($script:LastWingetLog)" } else { '' }
    if ($needsRebootFirst) {
        Add-Result -Component $Name -Status 'PENDENTE' -Details "Reinicie o Windows e execute o kit novamente. $lastProblem.$logHint"
        return $false
    }
    $status = if ($Optional) { 'PENDENTE' } else { 'FALHA' }
    Add-Result -Component $Name -Status $status -Details "$lastProblem.$logHint"
    return $false
}

# ---------------------------------------------------------------------------
# Componentes
# ---------------------------------------------------------------------------

function Get-Jdk21Home {
    $roots = @(
        (Join-Path $env:ProgramFiles 'Eclipse Adoptium'),
        (Join-Path $env:ProgramFiles 'Java')
    )
    $jdk = foreach ($root in $roots) {
        if (Test-Path -LiteralPath $root) {
            Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^jdk-?21' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'bin\java.exe')) }
        }
    }
    $selected = $jdk | Sort-Object -Property FullName -Descending | Select-Object -First 1
    if ($selected) { return $selected.FullName }
    return $null
}

function Set-JavaHome {
    $jdkHome = Get-Jdk21Home
    if ($jdkHome) {
        [Environment]::SetEnvironmentVariable('JAVA_HOME', $jdkHome, 'Machine')
        Add-MachinePath -PathToAdd (Join-Path $jdkHome 'bin')
        Add-Result -Component 'JAVA_HOME' -Status 'OK' -Details $jdkHome
    }
    else {
        Add-Result -Component 'JAVA_HOME' -Status 'AVISO' -Details 'JDK 21 não foi localizado para configurar JAVA_HOME.'
    }
}

function Install-VisualCppRuntime {
    # Dependência do VirtualBox, LibreOffice, XAMPP e PostgreSQL. Instalada antes
    # para que nenhum desses pacotes falhe na etapa de dependências do WinGet.
    [void](Install-WingetPackage -Name 'Visual C++ 2015+ (x64)' -CandidateIds @('Microsoft.VCRedist.2015+.x64') `
        -MachineDisplayNamePattern '*Visual C++ 2015-20* Redistributable (x64)*' -AllowVerifiedUnknownScopeFallback `
        -LocalArguments @('/install', '/quiet', '/norestart'))
    [void](Install-WingetPackage -Name 'Visual C++ 2015+ (x86)' -CandidateIds @('Microsoft.VCRedist.2015+.x86') `
        -MachineDisplayNamePattern '*Visual C++ 2015-20* Redistributable (x86)*' -AllowVerifiedUnknownScopeFallback `
        -LocalArguments @('/install', '/quiet', '/norestart'))
}

function Install-PostgreSQL {
    if ($SkipPostgreSQL) {
        Add-Result -Component 'PostgreSQL' -Status 'IGNORADO' -Details 'Opção -SkipPostgreSQL utilizada.'
        return
    }

    $service = Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($service) {
        Add-Result -Component 'PostgreSQL' -Status 'OK' -Details "Já instalado; serviço $($service.Name)."
        return
    }

    if (-not $PostgresCredential -and (Test-IsInteractive)) {
        Write-Host ''
        Write-Host 'Defina a senha da conta postgres. Ela não será gravada neste pacote.' -ForegroundColor Yellow
        $script:PostgresCredential = Get-Credential -UserName 'postgres' -Message 'Senha do PostgreSQL para este laboratório'
    }

    if (-not $PostgresCredential) {
        Add-Result -Component 'PostgreSQL' -Status 'PENDENTE' -Details 'Nenhuma credencial postgres foi fornecida.'
        return
    }

    $plainPassword = $PostgresCredential.GetNetworkCredential().Password
    if ([string]::IsNullOrWhiteSpace($plainPassword) -or $plainPassword -match "[`r`n]") {
        Add-Result -Component 'PostgreSQL' -Status 'FALHA' -Details 'A senha está vazia ou contém quebra de linha.'
        return
    }

    # Uma tentativa anterior que falhou deixa a pasta data sem serviço, e o
    # instalador recusa uma pasta de dados que não está vazia. Ela é renomeada.
    $dataDirectory = Join-Path $env:ProgramFiles "PostgreSQL\$PostgresMajor\data"
    if ((Test-Path -LiteralPath $dataDirectory) -and @(Get-ChildItem -LiteralPath $dataDirectory -Force -ErrorAction SilentlyContinue).Count) {
        $backupName = "data-tentativa-anterior-$runStamp"
        Rename-Item -LiteralPath $dataDirectory -NewName $backupName -ErrorAction Stop
        Add-Result -Component 'PostgreSQL (pasta antiga)' -Status 'AVISO' -Details "Pasta de dados de uma tentativa anterior renomeada para $backupName."
    }

    $optionPath = Join-Path $env:TEMP ("postgres-options-{0}.txt" -f ([Guid]::NewGuid().ToString('N')))
    try {
        # Sem BOM: com BOM a primeira chave do arquivo não era reconhecida.
        $optionLines = @(
            'mode=unattended'
            'unattendedmodeui=none'
            'superaccount=postgres'
            "superpassword=$plainPassword"
            'serverport=5432'
            'disable-components=stackbuilder'
        )
        [IO.File]::WriteAllLines($optionPath, [string[]]$optionLines, $utf8NoBom)

        # O --override substitui TODOS os parâmetros do manifesto, inclusive o
        # modo silencioso; por isso ele é repetido aqui antes do --optionfile.
        $override = "--mode unattended --unattendedmodeui none --optionfile `"$optionPath`""
        [void](Install-WingetPackage -Name 'PostgreSQL' -CandidateIds @("PostgreSQL.PostgreSQL.$PostgresMajor") `
            -Scope machine -Override $override `
            -LocalArguments @('--mode', 'unattended', '--unattendedmodeui', 'none', '--optionfile', $optionPath) `
            -MachineVerificationPaths @("C:\Program Files\PostgreSQL\$PostgresMajor\bin\psql.exe") `
            -AllowVerifiedUnknownScopeFallback)
    }
    finally {
        $plainPassword = $null
        if (Test-Path -LiteralPath $optionPath) {
            Remove-Item -LiteralPath $optionPath -Force -ErrorAction SilentlyContinue
        }
    }

    $service = Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($service -and $service.Status -ne 'Running') {
        try { Start-Service -Name $service.Name -ErrorAction Stop } catch { }
    }
}

function Install-NetBeans {
    $jdkHome = Get-Jdk21Home
    $parameters = @{
        Name                              = 'Apache NetBeans'
        CandidateIds                      = @('Apache.NetBeans')
        MachineDisplayNamePattern         = '*NetBeans*'
        MachineVerificationPaths          = @('C:\Program Files\NetBeans*\bin\netbeans64.exe', 'C:\Program Files\Apache-NetBeans*\netbeans\bin\netbeans64.exe', 'C:\Program Files\NetBeans*\netbeans\bin\netbeans64.exe')
        AllowVerifiedUnknownScopeFallback = $true
        LocalArguments                    = @('--silent')
    }
    if ($jdkHome) {
        $parameters['LocalArguments'] = @('--silent', '--javahome', $jdkHome)
        # O manifesto traz um JDK Liberica como dependência; com o Temurin 21 já
        # instalado ele é dispensado e o instalador recebe o JDK explicitamente.
        $parameters['SkipDependencies'] = $true
        $parameters['Override'] = "--silent --javahome `"$jdkHome`""
    }
    [void](Install-WingetPackage @parameters)
}

function New-UrlShortcut {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Url,
        [string]$DestinationDirectory
    )

    $desktop = $DestinationDirectory
    if (-not $desktop) {
        $desktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
    }
    if (-not $desktop) {
        $desktop = Join-Path $env:PUBLIC 'Desktop'
    }
    New-Item -ItemType Directory -Path $desktop -Force | Out-Null
    $shortcutPath = Join-Path $desktop "$Name.url"
    @(
        '[InternetShortcut]'
        "URL=$Url"
    ) | Set-Content -LiteralPath $shortcutPath -Encoding ASCII
}

function New-WindowsShortcut {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Target,
        [string]$WorkingDirectory,
        [string]$Arguments,
        [string]$DestinationDirectory
    )

    $desktop = $DestinationDirectory
    if (-not $desktop) {
        $desktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
    }
    if (-not $desktop) {
        $desktop = Join-Path $env:PUBLIC 'Desktop'
    }
    New-Item -ItemType Directory -Path $desktop -Force | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut((Join-Path $desktop "$Name.lnk"))
    $shortcut.TargetPath = $Target
    if ($WorkingDirectory) {
        $shortcut.WorkingDirectory = $WorkingDirectory
    }
    if ($Arguments) {
        $shortcut.Arguments = $Arguments
    }
    $shortcut.Save()
}

function Install-Visualg {
    if ($SkipVisualg) {
        Add-Result -Component 'VisuAlg 3' -Status 'IGNORADO' -Details 'Opção -SkipVisualg utilizada.'
        return
    }

    $destination = 'C:\Program Files\VisuAlg'
    $existing = Get-ChildItem -Path $destination, 'C:\VisuAlg' -Filter '*.exe' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'visualg' } |
        Select-Object -First 1
    if ($existing) {
        New-WindowsShortcut -Name 'VisuAlg 3' -Target $existing.FullName -WorkingDirectory $existing.DirectoryName
        Add-Result -Component 'VisuAlg 3' -Status 'OK' -Details "Já disponível em $($existing.FullName)."
        return
    }

    $archive = Find-PackageFile -Filters @('visualg*.rar')
    if (-not $archive) {
        New-UrlShortcut -Name 'VisuAlg Web - contingencia' -Url 'https://visualg.com.br/'
        Add-Result -Component 'VisuAlg 3' -Status 'PENDENTE' -Details 'Coloque visualg3.0.7.rar em Pacotes e execute novamente. Foi criado um atalho web de contingência.'
        return
    }

    # 7-Zip primeiro; se ele falhou, o tar.exe do Windows 11 também lê RAR.
    Expand-ArchiveFast -ArchivePath $archive.FullName -Destination $destination
    $exe = Get-ChildItem -LiteralPath $destination -Filter '*.exe' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'visualg' } |
        Select-Object -First 1

    if ($exe) {
        # O VisuAlg grava VISUALG30.INI na própria pasta; contas padrão precisam
        # de permissão de escrita nela.
        [void](Grant-LabUsersModify -TargetPath $destination)
        New-WindowsShortcut -Name 'VisuAlg 3' -Target $exe.FullName -WorkingDirectory $exe.DirectoryName
        Add-Result -Component 'VisuAlg 3' -Status 'OK' -Details $exe.FullName
    }
    else {
        Add-Result -Component 'VisuAlg 3' -Status 'FALHA' -Details "visualg30.exe não apareceu depois de extrair $($archive.Name)."
    }
}

function Install-PacketTracer {
    if ($SkipPacketTracer) {
        Add-Result -Component 'Cisco Packet Tracer' -Status 'IGNORADO' -Details 'Opção -SkipPacketTracer utilizada.'
        return
    }

    if (Test-MachineDisplayName -Pattern '*Packet Tracer*') {
        Add-Result -Component 'Cisco Packet Tracer' -Status 'OK' -Details 'Já consta no registro da máquina.'
        return
    }

    $installer = Find-PackageFile -Filters @('*Packet*Tracer*.exe')
    if (-not $installer) {
        Add-Result -Component 'Cisco Packet Tracer' -Status 'PENDENTE' -Details 'Baixe o instalador oficial pela conta NetAcad e coloque o EXE em Pacotes.'
        return
    }

    # Copiar para o disco local evita falhas de leitura do pendrive no meio da
    # instalação e o aviso de segurança de arquivos vindos da Internet.
    $localInstaller = Join-Path $script:CacheRoot $installer.Name
    if (-not (Test-Path -LiteralPath $localInstaller) -or (Get-Item -LiteralPath $localInstaller).Length -ne $installer.Length) {
        Copy-Item -LiteralPath $installer.FullName -Destination $localInstaller -Force
    }
    Unblock-File -LiteralPath $localInstaller -ErrorAction SilentlyContinue

    $packetLog = Join-Path $script:LogRoot "packet-tracer-$runStamp.log"
    $innoCodes = @{
        1 = 'o instalador não conseguiu iniciar'
        2 = 'cancelado antes de começar'
        3 = 'erro fatal na preparação'
        4 = 'erro fatal durante a instalação'
        5 = 'cancelado durante a instalação'
        6 = 'o instalador foi encerrado'
        7 = 'a preparação falhou (geralmente falta reiniciar o Windows)'
        8 = 'a preparação falhou e o Windows precisa ser reiniciado'
    }
    [void](Wait-InstallerIdle)
    Write-Host 'Instalando Cisco Packet Tracer a partir do pacote local...' -ForegroundColor Cyan
    $result = Invoke-LoggedProcess -FilePath $localInstaller `
        -Arguments @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/SP-', '/NORESTART', '/NOCANCEL', '/ALLUSERS', "/LOG=$packetLog") `
        -LogName 'packet-tracer' -TimeoutMinutes 45 -Quiet

    if (Test-MachineDisplayName -Pattern '*Packet Tracer*') {
        if ($result.ExitCode -eq 3010) { $script:RebootRequired = $true }
        Add-Result -Component 'Cisco Packet Tracer' -Status 'OK' -Details "Instalador local: $($installer.Name)"
    }
    else {
        $meaning = if ($innoCodes.ContainsKey($result.ExitCode)) { ": $($innoCodes[$result.ExitCode])" } elseif ($result.TimedOut) { ': tempo limite esgotado' } else { '' }
        if ($result.ExitCode -in @(7, 8)) { $script:RebootRequired = $true }
        Add-Result -Component 'Cisco Packet Tracer' -Status 'FALHA' -Details "Código $($result.ExitCode)$meaning. Consulte $packetLog."
    }
}

function Stage-PostmanPerUserInstaller {
    $stageRoot = Join-Path $env:ProgramData 'LabSetup\UserConfig\Packages\Postman'
    New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null

    $existing = Get-ChildItem -LiteralPath $stageRoot -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object -Property LastWriteTime -Descending |
        Where-Object { Test-TrustedPublisherSignature -Path $_.FullName -PublisherPattern 'Postman' } |
        Select-Object -First 1
    if ($existing) {
        Add-Result -Component 'Postman para todos os perfis' -Status 'OK' -Details "Instalador por usuário já armazenado em $($existing.FullName)."
        return $true
    }

    $localPostman = Find-PackageFile -Filters @('*.exe') -SubFolder 'WinGet\Postman.Postman'
    if ($localPostman -and (Test-TrustedPublisherSignature -Path $localPostman.FullName -PublisherPattern 'Postman')) {
        $localTarget = Join-Path $stageRoot 'local'
        New-Item -ItemType Directory -Path $localTarget -Force | Out-Null
        Copy-Item -LiteralPath $localPostman.FullName -Destination (Join-Path $localTarget $localPostman.Name) -Force
        Add-Result -Component 'Postman para todos os perfis' -Status 'OK' -Details "Instalador copiado de Pacotes: $($localPostman.Name)."
        return $true
    }

    $downloadRoot = Join-Path $stageRoot $runStamp
    New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null
    Write-Host 'Preparando o instalador do Postman para cada perfil de usuário...' -ForegroundColor Cyan
    $arguments = @(
        'download', '--id', 'Postman.Postman', '--exact', '--source', 'winget',
        '--architecture', 'x64', '--download-directory', $downloadRoot,
        '--disable-interactivity', '--accept-source-agreements', '--accept-package-agreements'
    )
    $installer = $null
    for ($attempt = 1; $attempt -le $RetryCount -and -not $installer; $attempt++) {
        $exitCode = Invoke-Winget -Arguments $arguments -LogName 'postman-download' -TimeoutMinutes 20
        $installer = Get-ChildItem -LiteralPath $downloadRoot -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue |
            Sort-Object -Property LastWriteTime -Descending |
            Where-Object { Test-TrustedPublisherSignature -Path $_.FullName -PublisherPattern 'Postman' } |
            Select-Object -First 1
        if (-not $installer -and $attempt -lt $RetryCount) {
            Write-Warning "Download do Postman sem instalador válido ($(Format-ExitCode $exitCode)); nova tentativa."
            Start-Sleep -Seconds (15 * $attempt)
        }
    }

    if ($installer) {
        Add-Result -Component 'Postman para todos os perfis' -Status 'OK' -Details "Instalador oficial validado e armazenado em $($installer.FullName)."
        return $true
    }

    Remove-Item -LiteralPath $downloadRoot -Recurse -Force -ErrorAction SilentlyContinue
    Add-Result -Component 'Postman para todos os perfis' -Status 'AVISO' -Details 'Não foi possível armazenar o instalador. Cada perfil tentará instalar o Postman pelo WinGet no primeiro acesso.'
    return $false
}

function Get-ArduinoExecutable {
    $paths = @(
        (Join-Path $env:ProgramFiles 'Arduino IDE\Arduino IDE.exe'),
        (Join-Path $env:ProgramFiles 'arduino-ide\Arduino IDE.exe')
    )
    foreach ($path in $paths) {
        if (Test-Path -LiteralPath $path) { return $path }
    }
    return $null
}

function Install-ArduinoAllUsers {
    if ((Get-ArduinoExecutable) -or (Test-MachineDisplayName -Pattern '*Arduino IDE*')) {
        Add-Result -Component 'Arduino IDE (todos os usuários)' -Status 'OK' -Details 'Já instalado no escopo da máquina.'
        return
    }

    $msi = Find-PackageFile -Filters @('arduino-ide_*_Windows_64bit.msi')
    if (-not $msi) {
        $msi = Find-PackageFile -Filters @('*.msi') -SubFolder 'WinGet\ArduinoSA.IDE.stable'
    }

    if ($msi -and (Test-TrustedPublisherSignature -Path $msi.FullName -PublisherPattern 'Arduino')) {
        [void](Wait-InstallerIdle)
        Write-Host 'Instalando Arduino IDE pelo MSI local, no escopo da máquina...' -ForegroundColor Cyan
        $msiLog = Join-Path $script:LogRoot "arduino-msi-$runStamp.log"
        $msiLocal = Copy-ToLocalCache -File $msi
        $result = Invoke-LoggedProcess -FilePath 'msiexec.exe' `
            -Arguments @('/i', $msiLocal, '/qn', '/norestart', 'ALLUSERS=1', 'MSIINSTALLPERUSER=0', '/l*v', $msiLog) `
            -LogName 'arduino-msi' -TimeoutMinutes 30 -Quiet
        if ($result.ExitCode -in @(3010, 1641)) { $script:RebootRequired = $true }
        if ((Get-ArduinoExecutable) -or (Test-MachineDisplayName -Pattern '*Arduino IDE*')) {
            Add-Result -Component 'Arduino IDE (todos os usuários)' -Status 'OK' -Details "MSI local instalado por máquina: $($msi.Name)"
            return
        }
        Write-Warning "msiexec retornou $($result.ExitCode) (log: $msiLog). Tentando pelo WinGet."
    }
    elseif ($msi) {
        Write-Warning "A assinatura de $($msi.Name) não é válida; o MSI local será ignorado."
    }

    # O manifesto ArduinoSA.IDE.stable tem o MSI oficial com escopo de máquina.
    # Assim não é preciso consultar a API do GitHub (limite de 60/hora por IP).
    [void](Install-WingetPackage -Name 'Arduino IDE (todos os usuários)' -CandidateIds @('ArduinoSA.IDE.stable') `
        -Scope machine -InstallerType 'wix' `
        -MachineDisplayNamePattern '*Arduino IDE*' `
        -MachineVerificationPaths @((Join-Path $env:ProgramFiles 'Arduino IDE\Arduino IDE.exe'), (Join-Path $env:ProgramFiles 'arduino-ide\Arduino IDE.exe')))
}

function Get-NmapExecutable {
    foreach ($path in @('C:\Program Files (x86)\Nmap\nmap.exe', 'C:\Program Files\Nmap\nmap.exe')) {
        if (Test-Path -LiteralPath $path) { return $path }
    }
    return $null
}

function Test-NpcapInstalled {
    return ((Test-Path -LiteralPath (Join-Path $env:SystemRoot 'System32\Npcap\wpcap.dll')) -or
        [bool](Get-Service -Name 'npcap' -ErrorAction SilentlyContinue))
}

function Install-NmapInteractive {
    if ($SkipNmap) {
        Add-Result -Component 'Nmap + Npcap' -Status 'IGNORADO' -Details 'Opção -SkipNmap utilizada.'
        return
    }

    $nmap = Get-NmapExecutable
    if ($nmap -and (Test-NpcapInstalled)) {
        Add-MachinePath -PathToAdd (Split-Path -Path $nmap -Parent)
        Add-Result -Component 'Nmap + Npcap' -Status 'OK' -Details "Já instalado: $nmap"
        return
    }

    $installer = Find-PackageFile -Filters @('nmap-*-setup.exe')
    $installerPath = if ($installer) { Copy-ToLocalCache -File $installer } else { $null }

    if (-not $installerPath) {
        $listing = Get-RemoteText -Uri 'https://nmap.org/dist/'
        $versions = @([Regex]::Matches($listing, 'nmap-([0-9]+\.[0-9]+)-setup\.exe') |
            ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique |
            Sort-Object -Property { [Version]$_ } -Descending)
        if (-not $versions.Count) {
            throw 'Não foi possível identificar o instalador atual do Nmap em nmap.org/dist.'
        }
        $fileName = "nmap-$($versions[0])-setup.exe"
        $installerPath = Join-Path $script:CacheRoot $fileName
        Save-RemoteFile -Uri "https://nmap.org/dist/$fileName" -Destination $installerPath
    }

    if (-not (Test-TrustedPublisherSignature -Path $installerPath -PublisherPattern 'Insecure\.Com')) {
        throw "A assinatura de $installerPath não é do Nmap Project (Insecure.Com LLC)."
    }

    if ($SkipInteractiveInstallers -or -not (Test-IsInteractive)) {
        Add-Result -Component 'Nmap + Npcap' -Status 'PENDENTE' -Details "O Nmap gratuito não tem instalação silenciosa. Execute $installerPath manualmente nesta máquina."
        return
    }

    Write-Host ''
    Write-Host '------------------------------------------------------------' -ForegroundColor Yellow
    Write-Host ' NMAP + NPCAP: ETAPA COM CLIQUES' -ForegroundColor Yellow
    Write-Host '------------------------------------------------------------' -ForegroundColor Yellow
    Write-Host 'A versão gratuita do Nmap e do Npcap não aceita instalação silenciosa'
    Write-Host '(só a edição OEM, paga). O instalador vai abrir agora: aceite a licença'
    Write-Host 'e clique em Avançar até o fim, inclusive na janela do Npcap.'
    Write-Host ''
    $process = Start-Process -FilePath $installerPath -PassThru
    $process.WaitForExit()

    $nmap = Get-NmapExecutable
    if ($nmap) {
        Add-MachinePath -PathToAdd (Split-Path -Path $nmap -Parent)
    }
    if ($nmap -and (Test-NpcapInstalled)) {
        Add-Result -Component 'Nmap + Npcap' -Status 'OK' -Details "Instalado com o assistente: $nmap"
    }
    elseif ($nmap) {
        Add-Result -Component 'Nmap + Npcap' -Status 'AVISO' -Details 'Nmap instalado, mas o Npcap não foi encontrado; varreduras que capturam pacotes não funcionarão.'
    }
    else {
        Add-Result -Component 'Nmap + Npcap' -Status 'PENDENTE' -Details "O assistente foi fechado sem instalar. Execute $installerPath novamente."
    }
}

function Configure-SharedMachineAccess {
    $sharedRoots = @(
        'C:\xampp'
    )
    foreach ($root in $sharedRoots) {
        if (Test-Path -LiteralPath $root) {
            if (-not (Grant-LabUsersModify -TargetPath $root)) {
                Add-Result -Component 'Permissões compartilhadas' -Status 'AVISO' -Details "Não foi possível conceder modificação ao grupo Usuários em $root."
            }
        }
    }

    $machinePaths = @(
        'C:\xampp\php',
        'C:\xampp\mysql\bin'
    )
    $postgresRoot = Join-Path $env:ProgramFiles 'PostgreSQL'
    if (Test-Path -LiteralPath $postgresRoot) {
        $postgresVersion = Get-ChildItem -LiteralPath $postgresRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^[0-9]+$' } |
            Sort-Object -Property @{ Expression = { [int]$_.Name }; Descending = $true } |
            Select-Object -First 1
        if ($postgresVersion) {
            $machinePaths += (Join-Path $postgresVersion.FullName 'bin')
        }
    }
    foreach ($path in $machinePaths) {
        if (Test-Path -LiteralPath $path) {
            Add-MachinePath -PathToAdd $path
        }
    }
    Add-Result -Component 'Acesso compartilhado' -Status 'OK' -Details 'PATH da máquina e permissões das ferramentas compartilhadas foram configurados para todos os usuários.'
}

function Register-PerUserConfiguration {
    $sourceScript = Join-Path $PSScriptRoot 'Configure-LabUser.ps1'
    if (-not (Test-Path -LiteralPath $sourceScript)) {
        throw 'Configure-LabUser.ps1 não foi localizado no kit.'
    }

    $targetRoot = Join-Path $env:ProgramData 'LabSetup\UserConfig'
    $targetScript = Join-Path $targetRoot 'Configure-LabUser.ps1'
    New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
    Copy-Item -LiteralPath $sourceScript -Destination $targetScript -Force

    $runKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    New-Item -Path $runKey -Force | Out-Null
    $runCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$targetScript`" -Automatic"
    New-ItemProperty -Path $runKey -Name 'LabSetupConfigurarUsuario' -PropertyType String -Value $runCommand -Force | Out-Null
    Add-Result -Component 'Configuração de todos os perfis' -Status 'OK' -Details 'Postman, extensões do VS Code e modelos serão preparados automaticamente no primeiro acesso de cada usuário.'
}

function Find-FirstApplicationExecutable {
    param(
        [string[]]$ExactPatterns,
        [string[]]$SearchRoots,
        [string[]]$FileNames
    )

    foreach ($pattern in @($ExactPatterns)) {
        if (-not $pattern) { continue }
        $item = Get-Item -Path $pattern -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer } |
            Select-Object -First 1
        if ($item) { return $item.FullName }
    }

    foreach ($rootPattern in @($SearchRoots)) {
        if (-not $rootPattern) { continue }
        $roots = @(Get-Item -Path $rootPattern -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer })
        foreach ($root in $roots) {
            foreach ($fileName in @($FileNames)) {
                $item = Get-ChildItem -LiteralPath $root.FullName -Filter $fileName -File -Recurse -Depth 3 -ErrorAction SilentlyContinue |
                    Select-Object -First 1
                if ($item) { return $item.FullName }
            }
        }
    }
    return $null
}

function New-SharedLabShortcuts {
    $commonDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
    if (-not $commonDesktop) { $commonDesktop = Join-Path $env:PUBLIC 'Desktop' }
    $commonPrograms = [Environment]::GetFolderPath('CommonPrograms')
    if (-not $commonPrograms) { $commonPrograms = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs' }
    $directories = @(
        (Join-Path $commonDesktop 'Laboratorio de Informatica'),
        (Join-Path $commonPrograms 'Laboratorio de Informatica')
    )

    $apps = @(
        @{ Name = 'LibreOffice'; Exact = @((Join-Path $env:ProgramFiles 'LibreOffice\program\soffice.exe')); Roots = @(); Files = @() },
        @{ Name = 'XAMPP'; Exact = @('C:\xampp\xampp-control.exe'); Roots = @(); Files = @() },
        @{ Name = 'Visual Studio Code'; Exact = @((Join-Path $env:ProgramFiles 'Microsoft VS Code\Code.exe')); Roots = @(); Files = @() },
        @{ Name = 'Apache NetBeans'; Exact = @(); Roots = @((Join-Path $env:ProgramFiles 'NetBeans*'), (Join-Path $env:ProgramFiles 'Apache-NetBeans*'), (Join-Path $env:ProgramFiles 'WinGet\Packages\Apache.NetBeans*')); Files = @('netbeans64.exe') },
        @{ Name = 'Eclipse IDE'; Exact = @(); Roots = @((Join-Path $env:ProgramFiles 'LabApps\Eclipse*'), (Join-Path $env:ProgramFiles 'WinGet\Packages\EclipseFoundation.Eclipse.Java*'), (Join-Path $env:ProgramFiles 'Eclipse*')); Files = @('eclipse.exe') },
        @{ Name = 'Cisco Packet Tracer'; Exact = @((Join-Path $env:ProgramFiles 'Cisco Packet Tracer*\bin\PacketTracer.exe'), (Join-Path $env:ProgramFiles 'Cisco Packet Tracer*\PacketTracer.exe')); Roots = @(); Files = @() },
        @{ Name = 'Oracle VirtualBox'; Exact = @((Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VirtualBox.exe')); Roots = @(); Files = @() },
        @{ Name = 'Arduino IDE'; Exact = @((Join-Path $env:ProgramFiles 'Arduino IDE\Arduino IDE.exe'), (Join-Path $env:ProgramFiles 'arduino-ide\Arduino IDE.exe')); Roots = @(); Files = @() },
        @{ Name = 'Android Studio'; Exact = @((Join-Path $env:ProgramFiles 'Android\Android Studio\bin\studio64.exe')); Roots = @(); Files = @() },
        @{ Name = 'pgAdmin 4'; Exact = @((Join-Path $env:ProgramFiles 'PostgreSQL\*\pgAdmin 4\runtime\pgAdmin4.exe'), (Join-Path $env:ProgramFiles 'PostgreSQL\*\pgAdmin 4\bin\pgAdmin4.exe'), (Join-Path $env:ProgramFiles 'pgAdmin 4\runtime\pgAdmin4.exe')); Roots = @(); Files = @() },
        @{ Name = 'Zenmap (Nmap)'; Exact = @('C:\Program Files (x86)\Nmap\zenmap.exe', 'C:\Program Files\Nmap\zenmap.exe'); Roots = @(); Files = @() }
    )

    $createdApps = 0
    foreach ($app in $apps) {
        $target = Find-FirstApplicationExecutable -ExactPatterns $app.Exact -SearchRoots $app.Roots -FileNames $app.Files
        if (-not $target) { continue }
        foreach ($directory in $directories) {
            New-WindowsShortcut -Name $app.Name -Target $target -WorkingDirectory (Split-Path -Path $target -Parent) -DestinationDirectory $directory
        }
        $createdApps++
    }

    $webLinks = @(
        @{ Name = 'Figma Web'; Url = 'https://www.figma.com/' },
        @{ Name = 'Postman Web'; Url = 'https://web.postman.co/' },
        @{ Name = 'Spring Initializr'; Url = 'https://start.spring.io/' },
        @{ Name = 'Selenium Documentation'; Url = 'https://www.selenium.dev/documentation/' }
    )
    foreach ($link in $webLinks) {
        foreach ($directory in $directories) {
            New-UrlShortcut -Name $link.Name -Url $link.Url -DestinationDirectory $directory
        }
    }

    Add-Result -Component 'Atalhos para todos os usuários' -Status 'OK' -Details "$createdApps aplicativos e $($webLinks.Count) links web publicados na Área de Trabalho e no menu Iniciar."
}

function Install-Maven {
    $existing = Get-Command 'mvn.cmd' -ErrorAction SilentlyContinue
    if ($existing) {
        Add-Result -Component 'Apache Maven' -Status 'OK' -Details "Já disponível em $($existing.Source)."
        return
    }

    $localArchive = Find-PackageFile -Filters @('apache-maven-*-bin.zip')
    $archivePath = $null
    $version = $null

    if ($localArchive -and $localArchive.Name -match '^apache-maven-([0-9.]+)-bin\.zip$') {
        $archivePath = $localArchive.FullName
        $version = $Matches[1]
        $hashFile = "$($localArchive.FullName).sha512"
        if (Test-Path -LiteralPath $hashFile) {
            $expectedHash = ((Get-Content -LiteralPath $hashFile -Raw).Trim() -split '\s+')[0]
            if (-not (Test-FileHashValue -Path $archivePath -ExpectedHash $expectedHash -Algorithm SHA512)) {
                Add-Result -Component 'Apache Maven' -Status 'FALHA' -Details "O hash SHA-512 de $($localArchive.Name) não confere."
                return
            }
        }
    }
    else {
        # A listagem do espelho é mais estável que a página download.cgi. Fica
        # na linha 3.x (a usada por Spring, NetBeans e Eclipse); o Maven 4 mora
        # em outra pasta (maven-4) e quebrava a URL montada na revisão 3.
        Write-Host 'Consultando a versão estável do Apache Maven 3...' -ForegroundColor Cyan
        $listing = Get-RemoteText -Uri 'https://dlcdn.apache.org/maven/maven-3/'
        $versions = @([Regex]::Matches($listing, 'href="(3\.[0-9]+\.[0-9]+)/"') |
            ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique |
            Sort-Object -Property { [Version]$_ } -Descending)
        if (-not $versions.Count) {
            Add-Result -Component 'Apache Maven' -Status 'FALHA' -Details 'Não foi possível identificar a versão estável no espelho oficial.'
            return
        }
        $version = $versions[0]
        $fileName = "apache-maven-$version-bin.zip"
        $archivePath = Join-Path $script:CacheRoot $fileName
        $primary = "https://dlcdn.apache.org/maven/maven-3/$version/binaries/$fileName"
        $archive = "https://archive.apache.org/dist/maven/maven-3/$version/binaries/$fileName"
        $expectedHash = ((Get-RemoteText -Uri "$primary.sha512").Trim() -split '\s+')[0]
        Save-RemoteFile -Uri $primary -MirrorUris @($archive) -Destination $archivePath -ExpectedHash $expectedHash -Algorithm SHA512
    }

    $devRoot = 'C:\Dev'
    $mavenRoot = Join-Path $devRoot "apache-maven-$version"
    Expand-ArchiveFast -ArchivePath $archivePath -Destination $devRoot
    $mvn = Join-Path $mavenRoot 'bin\mvn.cmd'
    if (Test-Path -LiteralPath $mvn) {
        [Environment]::SetEnvironmentVariable('MAVEN_HOME', $mavenRoot, 'Machine')
        Add-MachinePath -PathToAdd (Join-Path $mavenRoot 'bin')
        Add-Result -Component 'Apache Maven' -Status 'OK' -Details "$mavenRoot (SHA-512 validado)"
    }
    else {
        Add-Result -Component 'Apache Maven' -Status 'FALHA' -Details "mvn.cmd não foi localizado em $mavenRoot."
    }
}

function Get-GitExecutable {
    $command = Get-Command 'git.exe' -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    foreach ($path in @((Join-Path $env:ProgramFiles 'Git\cmd\git.exe'), (Join-Path ${env:ProgramFiles(x86)} 'Git\cmd\git.exe'))) {
        if ($path -and (Test-Path -LiteralPath $path)) { return $path }
    }
    return $null
}

function Add-GitSafeDirectory {
    param([Parameter(Mandatory = $true)][string]$Directory)

    # O Flutter é um repositório Git. Pasta criada pelo administrador e usada por
    # conta padrão gera "detected dubious ownership" e o flutter não roda.
    $git = Get-GitExecutable
    if (-not $git) {
        Write-Warning 'git.exe não encontrado; não foi possível liberar o Flutter para contas padrão.'
        return $false
    }
    $gitPath = $Directory.Replace('\', '/')
    $current = Invoke-NativeCommand -FilePath $git -Arguments @('config', '--system', '--get-all', 'safe.directory')
    if (@($current.Output | Where-Object { $_.Trim() -ieq $gitPath }).Count) { return $true }
    $result = Invoke-NativeCommand -FilePath $git -Arguments @('config', '--system', '--add', 'safe.directory', $gitPath)
    return ($result.ExitCode -eq 0)
}

function Install-Flutter {
    if ($SkipFlutter) {
        Add-Result -Component 'Flutter + Dart' -Status 'IGNORADO' -Details 'Opção -SkipFlutter utilizada.'
        return
    }

    $flutterBat = Join-Path $FlutterRoot 'bin\flutter.bat'
    if (-not (Test-Path -LiteralPath $flutterBat)) {
        $localArchive = Find-PackageFile -Filters @('flutter_windows_*stable.zip')
        $archivePath = $null

        if ($localArchive) {
            $archivePath = $localArchive.FullName
        }
        else {
            Write-Host 'Consultando a versão estável oficial do Flutter...' -ForegroundColor Cyan
            $releaseIndexUrl = 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
            $releaseIndex = Invoke-RestMethod -Uri $releaseIndexUrl -UseBasicParsing -TimeoutSec 60
            $stableHash = $releaseIndex.current_release.stable
            $release = $releaseIndex.releases | Where-Object { $_.hash -eq $stableHash } | Select-Object -First 1
            if (-not $release) {
                Add-Result -Component 'Flutter + Dart' -Status 'FALHA' -Details 'Não foi possível identificar a versão estável no índice oficial.'
                return
            }
            $archivePath = Join-Path $script:CacheRoot ([IO.Path]::GetFileName([string]$release.archive))
            $downloadUrl = "{0}/{1}" -f $releaseIndex.base_url.TrimEnd('/'), $release.archive
            Save-RemoteFile -Uri $downloadUrl -Destination $archivePath -ExpectedHash ([string]$release.sha256) -Algorithm SHA256
        }

        $devRoot = Split-Path -Path $FlutterRoot -Parent
        Write-Host 'Extraindo o Flutter SDK (pode levar alguns minutos)...' -ForegroundColor Cyan
        Expand-ArchiveFast -ArchivePath $archivePath -Destination $devRoot
    }

    if (-not (Test-Path -LiteralPath $flutterBat)) {
        Add-Result -Component 'Flutter + Dart' -Status 'FALHA' -Details "flutter.bat não foi localizado em $FlutterRoot."
        return
    }

    Add-MachinePath -PathToAdd (Join-Path $FlutterRoot 'bin')
    if (-not (Add-GitSafeDirectory -Directory $FlutterRoot)) {
        Add-Result -Component 'Flutter (Git)' -Status 'AVISO' -Details 'safe.directory não foi configurado; contas padrão podem ver "dubious ownership".'
    }
    $flutterResult = Invoke-LoggedProcess -FilePath $flutterBat -Arguments @('--version') -LogName 'flutter-version' -TimeoutMinutes 30
    [void](Grant-LabUsersModify -TargetPath $FlutterRoot)
    if ($flutterResult.ExitCode -eq 0) {
        Add-Result -Component 'Flutter + Dart' -Status 'OK' -Details "$FlutterRoot (Dart incluído no SDK Flutter)"
    }
    else {
        Add-Result -Component 'Flutter + Dart' -Status 'FALHA' `
            -Details "flutter --version retornou $($flutterResult.ExitCode). Log: $($flutterResult.LogFile)"
    }
}

function Get-AndroidCommandLineToolsRelease {
    # Índice oficial usado pelo próprio sdkmanager/Android Studio; traz URL e
    # SHA-1 de cada pacote. A revisão 3 procurava um hash na página HTML e às
    # vezes pegava o hash errado ("hash não confere").
    $xml = [xml](Get-RemoteText -Uri 'https://dl.google.com/android/repository/repository2-3.xml')
    $packages = $xml.SelectNodes("//*[local-name()='remotePackage'][@path='cmdline-tools;latest']")
    foreach ($package in $packages) {
        $channel = $package.SelectSingleNode("*[local-name()='channelRef']")
        if ($channel -and $channel.GetAttribute('ref') -ne 'channel-0') { continue }
        foreach ($archive in $package.SelectNodes(".//*[local-name()='archive']")) {
            $urlNode = $archive.SelectSingleNode(".//*[local-name()='complete']/*[local-name()='url']")
            $sumNode = $archive.SelectSingleNode(".//*[local-name()='complete']/*[local-name()='checksum']")
            $hostNode = $archive.SelectSingleNode("*[local-name()='host-os']")
            if (-not $urlNode) { continue }
            $isWindows = ($hostNode -and $hostNode.InnerText -eq 'windows') -or ($urlNode.InnerText -match '-win-')
            if (-not $isWindows) { continue }
            $fileName = $urlNode.InnerText.Trim()
            return [PSCustomObject]@{
                FileName = $fileName
                Url      = "https://dl.google.com/android/repository/$fileName"
                Sha1     = if ($sumNode) { $sumNode.InnerText.Trim() } else { $null }
            }
        }
    }
    throw 'As Android Command-line Tools para Windows não constam no índice oficial.'
}

function Install-AndroidSdk {
    if ($SkipAndroidSdk) {
        Add-Result -Component 'Android SDK' -Status 'IGNORADO' -Details 'Opção -SkipAndroidSdk utilizada.'
        return
    }

    if (-not $AcceptAndroidSdkLicenses) {
        Add-Result -Component 'Android SDK' -Status 'PENDENTE' -Details 'Os componentes do SDK exigem aceitação explícita. Execute novamente com -AcceptAndroidSdkLicenses.'
        return
    }

    $jdkHome = Get-Jdk21Home
    if (-not $jdkHome) {
        Add-Result -Component 'Android SDK' -Status 'FALHA' -Details 'O sdkmanager precisa do JDK 21, que não foi encontrado.'
        return
    }
    $env:JAVA_HOME = $jdkHome

    $sdkManager = Join-Path $AndroidSdkRoot 'cmdline-tools\latest\bin\sdkmanager.bat'
    $adb = Join-Path $AndroidSdkRoot 'platform-tools\adb.exe'
    $platform = Join-Path $AndroidSdkRoot "platforms\android-$AndroidApiLevel"
    $buildTools = Join-Path $AndroidSdkRoot "build-tools\$($AndroidApiLevel).0.0"
    $emulator = Join-Path $AndroidSdkRoot 'emulator\emulator.exe'
    $sdkReady = { (Test-Path -LiteralPath $adb) -and (Test-Path -LiteralPath $platform) -and (Test-Path -LiteralPath $buildTools) -and (Test-Path -LiteralPath $emulator) }

    # SDK completo preparado por Baixar-Pacotes.ps1 (android-sdk-api<N>.zip).
    $sdkArchive = Find-PackageFile -Filters @("android-sdk-api$AndroidApiLevel*.zip", 'android-sdk*.zip')
    if ($sdkArchive -and -not (& $sdkReady)) {
        Write-Host "Extraindo o Android SDK de Pacotes ($($sdkArchive.Name))..." -ForegroundColor Cyan
        Expand-ArchiveFast -ArchivePath $sdkArchive.FullName -Destination $AndroidSdkRoot
    }

    if (-not (Test-Path -LiteralPath $sdkManager)) {
        $localTools = Find-PackageFile -Filters @('commandlinetools-win-*_latest.zip')
        if ($localTools) {
            $zipPath = $localTools.FullName
        }
        else {
            $release = Get-AndroidCommandLineToolsRelease
            $zipPath = Join-Path $script:CacheRoot $release.FileName
            Write-Host 'Baixando Android Command-line Tools da fonte oficial...' -ForegroundColor Cyan
            if ($release.Sha1) {
                Save-RemoteFile -Uri $release.Url -Destination $zipPath -ExpectedHash $release.Sha1 -Algorithm SHA1
            }
            else {
                Save-RemoteFile -Uri $release.Url -Destination $zipPath
            }
        }

        $extractRoot = Join-Path $script:CacheRoot ("android-cli-{0}" -f ([Guid]::NewGuid().ToString('N')))
        try {
            Expand-ArchiveFast -ArchivePath $zipPath -Destination $extractRoot
            $source = Join-Path $extractRoot 'cmdline-tools'
            $target = Join-Path $AndroidSdkRoot 'cmdline-tools\latest'
            New-Item -ItemType Directory -Path $target -Force | Out-Null
            Copy-Item -Path (Join-Path $source '*') -Destination $target -Recurse -Force
        }
        finally {
            Remove-Item -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    [Environment]::SetEnvironmentVariable('ANDROID_HOME', $AndroidSdkRoot, 'Machine')
    [Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $AndroidSdkRoot, 'Machine')
    Add-MachinePath -PathToAdd (Join-Path $AndroidSdkRoot 'platform-tools')
    Add-MachinePath -PathToAdd (Join-Path $AndroidSdkRoot 'emulator')
    Add-MachinePath -PathToAdd (Join-Path $AndroidSdkRoot 'cmdline-tools\latest\bin')
    $env:JAVA_HOME = $jdkHome

    if (-not (Test-Path -LiteralPath $sdkManager)) {
        Add-Result -Component 'Android SDK' -Status 'FALHA' -Details 'sdkmanager.bat não foi localizado após a extração.'
        return
    }

    Write-Host 'Aceitando as licenças do Android SDK em nome da instituição...' -ForegroundColor Yellow
    $yesFile = Join-Path $script:CacheRoot 'android-licencas-sim.txt'
    [IO.File]::WriteAllText($yesFile, (("y`r`n") * 100), [Text.Encoding]::ASCII)
    $licenseResult = Invoke-LoggedProcess -FilePath $sdkManager `
        -Arguments @("--sdk_root=$AndroidSdkRoot", '--licenses') -StandardInputFile $yesFile `
        -LogName 'android-licencas' -TimeoutMinutes 10 -Quiet
    if ($licenseResult.ExitCode -ne 0) {
        Add-Result -Component 'Android SDK' -Status 'FALHA' `
            -Details "A aceitação das licenças retornou $($licenseResult.ExitCode). Log: $($licenseResult.LogFile)"
        return
    }

    $packages = @(
        'platform-tools',
        "platforms;android-$AndroidApiLevel",
        "build-tools;$($AndroidApiLevel).0.0",
        'emulator',
        'extras;google;usb_driver'
    )
    $exitCode = 0
    if (& $sdkReady) {
        Write-Host 'Componentes do Android SDK já presentes; nenhum download necessário.' -ForegroundColor DarkGray
    }
    for ($attempt = 1; $attempt -le $RetryCount -and -not (& $sdkReady); $attempt++) {
        Write-Host "Baixando componentes do Android SDK (tentativa $attempt/$RetryCount)..." -ForegroundColor Cyan
        $sdkResult = Invoke-LoggedProcess -FilePath $sdkManager `
            -Arguments (@("--sdk_root=$AndroidSdkRoot") + $packages) `
            -LogName 'android-sdk' -TimeoutMinutes 60 -Quiet
        $exitCode = $sdkResult.ExitCode
        if ($exitCode -eq 0 -and (& $sdkReady)) { break }
        if ($attempt -lt $RetryCount) { Start-Sleep -Seconds (20 * $attempt) }
    }

    if ((Test-Path -LiteralPath $adb) -and (Test-Path -LiteralPath $platform)) {
        [void](Grant-LabUsersModify -TargetPath $AndroidSdkRoot)
        Add-Result -Component 'Android SDK' -Status 'OK' -Details "API $AndroidApiLevel, Build-Tools, Platform-Tools e Emulator em $AndroidSdkRoot"
    }
    else {
        Add-Result -Component 'Android SDK' -Status 'FALHA' -Details "sdkmanager retornou $exitCode; veja Logs\android-sdk-*.log."
    }
}

function Copy-LabTemplates {
    $source = Join-Path $PSScriptRoot 'Modelos'
    if (-not (Test-Path -LiteralPath $source)) {
        Add-Result -Component 'Modelos Spring/Selenium' -Status 'AVISO' -Details 'Pasta Modelos não encontrada no pacote.'
        return
    }

    $commonDocuments = [Environment]::GetFolderPath('CommonDocuments')
    if (-not $commonDocuments) {
        $commonDocuments = Join-Path $env:PUBLIC 'Documents'
    }
    $destination = Join-Path $commonDocuments 'Lab-Templates'
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item -Path (Join-Path $source '*') -Destination $destination -Recurse -Force
    Add-Result -Component 'Modelos Spring/Selenium' -Status 'OK' -Details $destination
}

# ---------------------------------------------------------------------------
# Execução
# ---------------------------------------------------------------------------

$transcriptStarted = $false
try {
    try {
        Start-Transcript -LiteralPath $transcriptPath -Force | Out-Null
        $transcriptStarted = $true
    }
    catch {
        Write-Warning "Não foi possível iniciar o log: $($_.Exception.Message)"
    }
    Write-Host "Preparação do laboratório em $env:COMPUTERNAME (kit revisão $script:KitRevision)" -ForegroundColor Cyan
    Write-Host "Log: $transcriptPath" -ForegroundColor DarkGray

    Confirm-Agreements

    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    if ([Version]$os.Version -lt [Version]'10.0.22000') {
        throw "Este pacote foi preparado para Windows 11. Versão detectada: $($os.Version)."
    }
    if (-not [Environment]::Is64BitOperatingSystem) {
        throw 'É necessário Windows 11 de 64 bits.'
    }

    $systemDrive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
    $freeGB = [Math]::Round($systemDrive.FreeSpace / 1GB, 1)
    if ($freeGB -lt 35) {
        Add-Result -Component 'Espaço em disco' -Status 'AVISO' -Details "Somente $freeGB GB livres. Recomenda-se ao menos 35 GB."
    }
    else {
        Add-Result -Component 'Espaço em disco' -Status 'OK' -Details "$freeGB GB livres."
    }

    if (Test-PendingReboot) {
        Add-Result -Component 'Reinicialização pendente' -Status 'AVISO' -Details 'O Windows tem atualizações aguardando reinicialização; alguns instaladores podem falhar. Se houver falhas, reinicie e rode o kit de novo.'
    }

    # Acrescenta TLS 1.2 sem desligar TLS 1.3/padrões do sistema.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    # Arquivos copiados de um ZIP baixado carregam a marca "da Internet", que
    # pode abrir um aviso de segurança escondido e travar o instalador.
    Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -File -ErrorAction SilentlyContinue |
        Unblock-File -ErrorAction SilentlyContinue

    try {
        Initialize-Winget
    }
    catch {
        Add-Result -Component 'WinGet' -Status 'FALHA' -Details $_.Exception.Message
        throw
    }

    Invoke-LabStep -Component 'Visual C++ 2015+' -Action { Install-VisualCppRuntime }
    Invoke-LabStep -Component '7-Zip' -Action {
        [void](Install-WingetPackage -Name '7-Zip' -CandidateIds @('7zip.7zip') `
            -MachineVerificationPaths @('C:\Program Files\7-Zip\7z.exe') -AllowVerifiedUnknownScopeFallback `
            -LocalArguments @('/S'))
    }
    Invoke-LabStep -Component 'Git for Windows' -Action {
        [void](Install-WingetPackage -Name 'Git for Windows' -CandidateIds @('Git.Git') `
            -MachineVerificationPaths @('C:\Program Files\Git\cmd\git.exe') -AllowVerifiedUnknownScopeFallback `
            -LocalArguments @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', '/ALLUSERS'))
        Update-ProcessEnvironment
    }
    Invoke-LabStep -Component 'Java JDK/SDK 21 LTS' -Action {
        [void](Install-WingetPackage -Name 'Java JDK/SDK 21 LTS' -CandidateIds @('EclipseAdoptium.Temurin.21.JDK') `
            -MachineVerificationPaths @('C:\Program Files\Eclipse Adoptium\jdk-21*\bin\java.exe') -AllowVerifiedUnknownScopeFallback)
    }
    Invoke-LabStep -Component 'JAVA_HOME' -Action { Set-JavaHome }
    Invoke-LabStep -Component 'Apache Maven' -Action { Install-Maven }

    Invoke-LabStep -Component 'LibreOffice' -Action {
        [void](Install-WingetPackage -Name 'LibreOffice' -CandidateIds @('TheDocumentFoundation.LibreOffice') `
            -MachineVerificationPaths @('C:\Program Files\LibreOffice\program\soffice.exe') -AllowVerifiedUnknownScopeFallback)
    }
    Invoke-LabStep -Component 'XAMPP 8.2' -Action {
        [void](Install-WingetPackage -Name 'XAMPP 8.2' -CandidateIds @('ApacheFriends.Xampp.8.2') `
            -MachineVerificationPaths @('C:\xampp\xampp-control.exe') -AllowVerifiedUnknownScopeFallback `
            -LocalArguments @('--mode', 'unattended', '--unattendedmodeui', 'none'))
    }
    Invoke-LabStep -Component 'PostgreSQL' -Action { Install-PostgreSQL }

    Invoke-LabStep -Component 'Visual Studio Code' -Action {
        [void](Install-WingetPackage -Name 'Visual Studio Code' -CandidateIds @('Microsoft.VisualStudioCode') `
            -MachineVerificationPaths @('C:\Program Files\Microsoft VS Code\Code.exe') -AllowVerifiedUnknownScopeFallback `
            -LocalArguments @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/MERGETASKS=!runcode'))
    }
    Invoke-LabStep -Component 'Apache NetBeans' -Action { Install-NetBeans }
    Invoke-LabStep -Component 'Eclipse IDE for Java' -Action {
        [void](Install-WingetPackage -Name 'Eclipse IDE for Java' -CandidateIds @('EclipseFoundation.Eclipse.Java') `
            -Location 'C:\Program Files\LabApps\Eclipse' `
            -LocalZipDestination 'C:\Program Files\LabApps\Eclipse' `
            -MachineVerificationPaths @('C:\Program Files\LabApps\Eclipse\eclipse.exe', 'C:\Program Files\LabApps\Eclipse\eclipse\eclipse.exe') `
            -AllowVerifiedUnknownScopeFallback)
    }

    Invoke-LabStep -Component 'Oracle VirtualBox' -Action {
        [void](Install-WingetPackage -Name 'Oracle VirtualBox' -CandidateIds @('Oracle.VirtualBox') `
            -MachineVerificationPaths @('C:\Program Files\Oracle\VirtualBox\VBoxManage.exe') -AllowVerifiedUnknownScopeFallback `
            -LocalArguments @('--silent', '--ignore-reboot'))
    }
    Invoke-LabStep -Component 'Arduino IDE (todos os usuários)' -Action { Install-ArduinoAllUsers }
    Invoke-LabStep -Component 'Android Studio' -Action {
        [void](Install-WingetPackage -Name 'Android Studio' -CandidateIds @('Google.AndroidStudio') `
            -MachineVerificationPaths @('C:\Program Files\Android\Android Studio\bin\studio64.exe') -AllowVerifiedUnknownScopeFallback `
            -LocalArguments @('/S'))
    }

    Invoke-LabStep -Component 'VisuAlg 3' -Action { Install-Visualg }
    Invoke-LabStep -Component 'Cisco Packet Tracer' -Action { Install-PacketTracer }
    Invoke-LabStep -Component 'Flutter + Dart' -Action { Install-Flutter }
    Invoke-LabStep -Component 'Android SDK' -Action { Install-AndroidSdk }
    Invoke-LabStep -Component 'Postman para todos os perfis' -Action { [void](Stage-PostmanPerUserInstaller) }
    Invoke-LabStep -Component 'Acesso compartilhado' -Action { Configure-SharedMachineAccess }

    # Etapa com cliques fica por último, para o resto rodar sem ninguém por perto.
    Invoke-LabStep -Component 'Nmap + Npcap' -Action { Install-NmapInteractive }

    Invoke-LabStep -Component 'Atalhos web' -Action {
        New-SharedLabShortcuts
        Add-Result -Component 'Figma Web' -Status 'OK' -Details 'Atalho compartilhado criado; não há aplicativo web a instalar.'
        Add-Result -Component 'Spring Framework' -Status 'OK' -Details 'Maven/JDK instalados; atalho compartilhado e modelo incluídos.'
        Add-Result -Component 'Selenium' -Status 'OK' -Details 'É dependência de projeto; modelo Maven e documentação compartilhada incluídos.'
    }
    Invoke-LabStep -Component 'Modelos Spring/Selenium' -Action { Copy-LabTemplates }
    Invoke-LabStep -Component 'Configuração de todos os perfis' -Action { Register-PerUserConfiguration }

    if ($script:RebootRequired -or (Test-PendingReboot)) {
        Add-Result -Component 'Reinicialização' -Status 'AVISO' -Details 'Algum instalador pediu reinicialização. Reinicie antes de usar a máquina.'
    }
}
catch {
    $wingetFailure = @($script:Results | Where-Object { $_.Component -eq 'WinGet' -and $_.Status -eq 'FALHA' })
    if (-not $wingetFailure.Count) {
        Add-Result -Component 'Instalação geral' -Status 'FALHA' -Details $_.Exception.Message
    }
}
finally {
    try {
        $resultCsv = Join-Path $script:LogRoot "resultado-$($env:COMPUTERNAME)-$runStamp.csv"
        $script:Results | Export-Csv -LiteralPath $resultCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Resultado local: $resultCsv" -ForegroundColor Cyan
    }
    catch {
        Write-Warning "Não foi possível gravar o relatório CSV: $($_.Exception.Message)"
    }
    if ($transcriptStarted) {
        try { Stop-Transcript | Out-Null } catch { }
    }
}

# Esta é a única saída de pipeline intencional; o lançador local mostra o resumo.
$script:Results
