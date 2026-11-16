# VisuAlg 3.0.7 (Portugol) a partir do RAR do kit, com atalhos publicos e escrita para Usuarios
# (o VisuAlg grava VISUALG30.INI na propria pasta). Rodar como Administrador.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\kit.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
$dest = 'C:\Program Files (x86)\visualg3.0.7'
$rar = 'D:\kit\Pacotes\visualg3.0.7.rar'
if (-not (Test-Path $rar)) { L "VisuAlg FALHA: $rar nao encontrado"; return }
New-Item -ItemType Directory -Force $dest | Out-Null
& 'C:\Program Files\7-Zip\7z.exe' x $rar "-o$dest" -y -bso0 -bsp0; L "VisuAlg extraido (exit=$LASTEXITCODE)"
$exe = Get-ChildItem $dest -Recurse -Filter '*.exe' | Where-Object Name -match 'visualg' | Select-Object -First 1
if (-not $exe) { L 'VisuAlg FALHA: executavel nao encontrado apos extrair'; return }
& icacls.exe $exe.DirectoryName /grant '*S-1-5-32-545:(OI)(CI)M' /T /C /Q | Out-Null
$w = New-Object -ComObject WScript.Shell
foreach ($lnk in 'C:\Users\Public\Desktop\VisuAlg 3.lnk', 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\VisuAlg 3.lnk') {
    $s = $w.CreateShortcut($lnk); $s.TargetPath = $exe.FullName; $s.WorkingDirectory = $exe.DirectoryName; $s.Save()
}
L "VisuAlg OK: $($exe.FullName)"
