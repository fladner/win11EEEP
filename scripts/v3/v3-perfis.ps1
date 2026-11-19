# v3 do zero, passo 8 (parte 1). Roda como Administrador (agente user).
# O Aluno ainda nao tem perfil (nunca entrou): Postman e extensoes do VS Code vao para o perfil Default,
# que o Windows copia para cada usuario novo no primeiro logon. Assim nao ha perfil do Aluno na imagem e o
# problema de SID do NTUSER.DAT depois do sysprep nem aparece.
$ErrorActionPreference = 'Continue'
$log = 'C:\ProgramData\EEEPBuild\v3-perfis.log'
function L($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content $log $l; $l }
$def = 'C:\Users\Default'
$sh = New-Object -ComObject WScript.Shell
function Atalho($lnk, $target) {
    New-Item -ItemType Directory -Force (Split-Path $lnk) | Out-Null
    $s = $sh.CreateShortcut($lnk); $s.TargetPath = $target; $s.Save()
}

L '== Postman'
$pm = "$env:LOCALAPPDATA\Postman"
Get-Process Postman, Update -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*\Postman\*' } | Stop-Process -Force -ErrorAction SilentlyContinue
if (Test-Path "$pm\Postman.exe") {
    & robocopy.exe $pm "$def\AppData\Local\Postman" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    # destino com variavel de ambiente: cada usuario abre o proprio Postman
    Atalho "$def\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Postman.lnk" '%LOCALAPPDATA%\Postman\Postman.exe'
    Atalho "$def\Desktop\Postman.lnk" '%LOCALAPPDATA%\Postman\Postman.exe'
    L "Postman no Default: $(Test-Path "$def\AppData\Local\Postman\Postman.exe")"
} else { L 'FALHA: Postman nao instalado no Administrador' }

L '== Extensoes do VS Code'
$code = 'C:\Program Files\Microsoft VS Code\bin\code.cmd'
foreach ($e in 'vscjava.vscode-java-pack', 'vmware.vscode-boot-dev-pack', 'Dart-Code.dart-code', 'Dart-Code.flutter', 'Postman.postman-for-vscode') {
    $o = cmd /c "`"$code`" --install-extension $e --force 2>&1" | Select-Object -Last 1
    L "   $e -> $o"
}
$ext = "$env:USERPROFILE\.vscode\extensions"
if (Test-Path $ext) {
    & robocopy.exe $ext "$def\.vscode\extensions" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    # extensions.json guarda caminhos absolutos do Administrador; sem ele o VS Code relê a pasta
    Remove-Item "$def\.vscode\extensions\extensions.json", "$def\.vscode\extensions\.obsolete" -Force -ErrorAction SilentlyContinue
    L "extensoes no Default: $(@(Get-ChildItem "$def\.vscode\extensions" -Directory).Count)"
}

L '== Atalhos quebrados'
$sm = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs'
foreach ($l in Get-ChildItem 'C:\Users\Public\Desktop\*.lnk', 'C:\Users\Administrador\Desktop\*.lnk', "$sm\*.lnk", "$sm\*\*.lnk" -ErrorAction SilentlyContinue) {
    $t = $sh.CreateShortcut($l.FullName).TargetPath
    if (-not $t -or $t -notmatch '^[A-Z]:\\' -or (Test-Path -LiteralPath $t)) { continue }
    Remove-Item $l.FullName -Force; L "atalho quebrado removido: $($l.FullName) -> $t"
}
# o Aluno nao administra o XAMPP (servicos automaticos)
Remove-Item 'C:\Users\Public\Desktop\XAMPP Control Panel.lnk' -Force -ErrorAction SilentlyContinue
L 'fim v3-perfis'
