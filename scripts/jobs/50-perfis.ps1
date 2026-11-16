# Postman e extensoes do VS Code nos perfis Administrador e Aluno; limpeza do Flutter antigo do Aluno;
# atalhos quebrados; residuos do DAEMON Tools. Rodar como Administrador (agente user), com o Aluno deslogado.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\kit.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
function Shortcut($lnk, $target) { $s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk); $s.TargetPath = $target; $s.WorkingDirectory = Split-Path $target; $s.Save() }
$aluno = 'C:\Users\Aluno'

L '===== Postman ====='
$pm = "$env:LOCALAPPDATA\Postman\Postman.exe"
if (-not (Test-Path $pm)) {
    $src = (Get-ChildItem 'D:\kit\Pacotes\WinGet\Postman.Postman' -Filter *.exe | Select-Object -First 1).FullName
    Copy-Item $src "$env:TEMP\postman-setup.exe" -Force
    $p = Start-Process "$env:TEMP\postman-setup.exe" -ArgumentList '-s' -PassThru
    for ($i = 0; $i -lt 60 -and -not (Test-Path $pm); $i++) { Start-Sleep 5 }
    Start-Sleep 20
    Remove-Item "$env:TEMP\postman-setup.exe" -Force -ErrorAction SilentlyContinue
}
Get-Process Postman, Update -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*\Postman\*' } | Stop-Process -Force -ErrorAction SilentlyContinue
L "Postman (Administrador): $(Test-Path $pm)"
if (Test-Path $pm) {
    & robocopy.exe "$env:LOCALAPPDATA\Postman" "$aluno\AppData\Local\Postman" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    $smA = "$aluno\AppData\Roaming\Microsoft\Windows\Start Menu\Programs"
    New-Item -ItemType Directory -Force $smA | Out-Null
    Shortcut "$smA\Postman.lnk" "$aluno\AppData\Local\Postman\Postman.exe"
    Shortcut "$aluno\Desktop\Postman.lnk" "$aluno\AppData\Local\Postman\Postman.exe"
    L "Postman (Aluno): $(Test-Path "$aluno\AppData\Local\Postman\Postman.exe")"
}

L '===== Extensoes do VS Code ====='
$code = 'C:\Program Files\Microsoft VS Code\bin\code.cmd'
foreach ($e in 'vscjava.vscode-java-pack', 'vmware.vscode-boot-dev-pack', 'Dart-Code.dart-code', 'Dart-Code.flutter', 'Postman.postman-for-vscode') {
    $o = cmd /c "`"$code`" --install-extension $e --force 2>&1" | Select-Object -Last 1
    L "   $e -> $o"
}
$ext = "$env:USERPROFILE\.vscode\extensions"
if (Test-Path $ext) {
    & robocopy.exe $ext "$aluno\.vscode\extensions" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    $j = "$aluno\.vscode\extensions\extensions.json"
    if (Test-Path $j) { $t = [IO.File]::ReadAllText($j) -replace '/Users/Administrador/', '/Users/Aluno/' -replace '\\\\Users\\\\Administrador\\\\', '\\Users\\Aluno\\'; [IO.File]::WriteAllText($j, $t, (New-Object Text.UTF8Encoding $false)) }
    L "extensoes no perfil do Aluno: $(@(Get-ChildItem "$aluno\.vscode\extensions" -Directory).Count)"
}

L '===== Flutter antigo do Aluno ====='
if (Test-Path "$aluno\flutter") { cmd /c "rd /s /q `"$aluno\flutter`""; L "C:\Users\Aluno\flutter removido: $(-not (Test-Path "$aluno\flutter"))" }
& reg.exe load HKU\EEEP_Aluno "$aluno\NTUSER.DAT" | Out-Null
if ($LASTEXITCODE -eq 0) {
    try {
        $k = [Microsoft.Win32.Registry]::Users.OpenSubKey('EEEP_Aluno\Environment', $true)
        if ($k) {
            $cur = [string]$k.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
            $new = (($cur -split ';') | Where-Object { $_ -and $_ -notmatch 'Aluno\\flutter|%USERPROFILE%\\flutter' }) -join ';'
            if ($new -ne $cur) { $k.SetValue('Path', $new, 'ExpandString'); L "PATH do Aluno ajustado: $new" } else { L 'PATH do Aluno sem entradas do Flutter antigo' }
            $k.Close()
        }
    } finally { [gc]::Collect(); Start-Sleep 1; & reg.exe unload HKU\EEEP_Aluno | Out-Null }
} else { L 'AVISO: nao foi possivel abrir o perfil do Aluno (logado?)' }

L '===== Atalhos ====='
$w = New-Object -ComObject WScript.Shell
$fix = @{ 'Inkscape' = 'C:\Program Files\Inkscape\bin\inkscape.exe'; 'MySQL Workbench' = (Get-ChildItem 'C:\Program Files\MySQL\MySQL Workbench*\MySQLWorkbench.exe' -ErrorAction SilentlyContinue | Select-Object -First 1).FullName }
$sm = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs'
foreach ($l in Get-ChildItem 'C:\Users\*\Desktop\*.lnk', "$sm\*.lnk", "$sm\*\*.lnk" -ErrorAction SilentlyContinue) {
    $t = $w.CreateShortcut($l.FullName).TargetPath
    if (-not $t -or $t -notmatch '^[A-Z]:\\' -or (Test-Path -LiteralPath $t)) { continue }
    $new = $fix[$l.BaseName]
    if ($new -and (Test-Path $new)) { Shortcut $l.FullName $new; L "atalho corrigido: $($l.FullName)" } else { Remove-Item $l.FullName -Force; L "atalho quebrado removido: $($l.FullName)" }
}
# o Aluno nao administra o XAMPP (servicos automaticos): sem atalho do painel nos perfis comuns
Remove-Item 'C:\Users\Aluno\Desktop\XAMPP Control Panel.lnk', 'C:\Users\CREDE\Desktop\XAMPP Control Panel.lnk' -Force -ErrorAction SilentlyContinue

L '===== Residuos do DAEMON Tools ====='
foreach ($d in 'dtlitescsibus', 'dtliteusbbus') { & sc.exe delete $d | Out-Null; L "driver $d removido do registro (exit=$LASTEXITCODE)" }
Remove-Item 'C:\ProgramData\Disc-Soft', 'C:\Program Files\DAEMON Tools Lite' -Recurse -Force -ErrorAction SilentlyContinue

L "Android Studio: $(Test-Path 'C:\Program Files\Android\Android Studio\bin\studio64.exe')"
L 'fim dos perfis'
