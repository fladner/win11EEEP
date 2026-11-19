# v3 do zero, passo 6 (parte 1): SimulIDE 1.1.0 (WinGet) e Open FluidSim v1.0 (release oficial do autor no GitHub,
# gabrielnaves/OpenFluidSim). Ambos gratuitos; ficam em pastas da maquina com atalhos publicos.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$log = 'C:\ProgramData\EEEPBuild\v3-simuladores.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
$sh = New-Object -ComObject WScript.Shell
function Atalho($nome, $exe) {
    foreach ($d in 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs', 'C:\Users\Public\Desktop') {
        $s = $sh.CreateShortcut("$d\$nome.lnk"); $s.TargetPath = $exe; $s.WorkingDirectory = Split-Path $exe; $s.Save()
    }
    L "atalhos: $nome -> $exe"
}

L '== SimulIDE (WinGet, escopo maquina)'
$o = cmd /c 'winget install --id SimulIDE.SimulIDE --exact --source winget --scope machine --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1'
L ("   exit=0x{0:X8} {1}" -f $LASTEXITCODE, (($o | Where-Object { $_ -match '\w{4}' -and $_ -notmatch '[\u2588\u2592]' } | Select-Object -Last 1) -join ''))
$se = Get-ChildItem 'C:\Program Files\WinGet\Packages', 'C:\Program Files\SimulIDE*', 'C:\Program Files (x86)\SimulIDE*' -Recurse -Filter 'simulide.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($se) {
    L "   simulide.exe: $($se.FullName)"
    if (-not (Get-ChildItem 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs' -Recurse -Filter 'SimulIDE*.lnk' -ErrorAction SilentlyContinue)) { Atalho 'SimulIDE' $se.FullName }
} else { L '   FALHA: simulide.exe nao encontrado' }

L '== Open FluidSim v1.0 (GitHub gabrielnaves/OpenFluidSim)'
$z = 'C:\ProgramData\EEEPBuild\openfluidsim-windows.zip'
try {
    Invoke-WebRequest 'https://github.com/gabrielnaves/OpenFluidSim/releases/download/v1.0/windows.zip' -OutFile $z -UseBasicParsing
    L "   zip: $([math]::Round((Get-Item $z).Length/1MB,1)) MB SHA256=$((Get-FileHash $z -Algorithm SHA256).Hash)"
    $dest = 'C:\Program Files\OpenFluidSim'
    & 'C:\Program Files\7-Zip\7z.exe' x $z "-o$dest" -y -bso0 -bsp0; L "   extraido (exit=$LASTEXITCODE)"
    $exe = Get-ChildItem $dest -Recurse -Filter '*.exe' | Where-Object Name -notmatch 'UnityCrashHandler' | Select-Object -First 1
    if ($exe) { L "   exe: $($exe.FullName) assinatura=$((Get-AuthenticodeSignature $exe.FullName).Status)"; Atalho 'Open FluidSim' $exe.FullName } else { L '   FALHA: exe nao encontrado' }
} catch { L "   FALHA: $($_.Exception.Message)" }
Remove-Item $z -Force -ErrorAction SilentlyContinue
