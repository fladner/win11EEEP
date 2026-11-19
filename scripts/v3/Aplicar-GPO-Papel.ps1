# v3: politicas locais e papel de parede. Roda como Administrador (modo de auditoria ou agente SYSTEM).
#   1. Restricoes do ALUNO (as 11 regras de usuario da imagem antiga: papel de parede, temas, cores, protecao de tela,
#      ponteiros, sons) -> politica local de "Nao administradores" (GroupPolicyUsers\S-1-5-32-545).
#      SID fixo do Windows: sobrevive ao sysprep. O Administrador NAO recebe essas restricoes.
#   2. Papel de parede C:\wallpaper.png para TODOS os usuarios -> politica local geral (Wallpaper/WallpaperStyle).
#   3. Tela de bloqueio e de login com a mesma imagem -> PersonalizationCSP (funciona no Pro) + as 3 regras de
#      maquina da imagem antiga (nao trocar tela de bloqueio nem fundo do Iniciar).
param([string]$Src = (Join-Path $PSScriptRoot 'gpo'))
$ErrorActionPreference = 'Stop'
$img = 'C:\wallpaper.png'
$old = Join-Path $Src 'Windows\System32\GroupPolicy'
Copy-Item (Join-Path $Src 'wallpaper.png') $img -Force

function Read-Pol([string]$f) {
    $b = [IO.File]::ReadAllBytes($f); $s = [Text.Encoding]::Unicode.GetString($b, 8, $b.Length - 8)
    $r = @()
    foreach ($m in [regex]::Matches($s, '\[(.*?);(.*?);(.)\x00;(..);', [Text.RegularExpressions.RegexOptions]::Singleline)) {
        $size = [int][char]$m.Groups[4].Value[0] + 65536 * [int][char]$m.Groups[4].Value[1]
        $data = [Text.Encoding]::Unicode.GetBytes($s.Substring($m.Index + $m.Length, [math]::Ceiling($size / 2)))[0..($size - 1)]
        $r += [pscustomobject]@{ Key = $m.Groups[1].Value.TrimEnd([char]0); Name = $m.Groups[2].Value.TrimEnd([char]0); Type = [int][char]$m.Groups[3].Value; Data = [byte[]]$data }
    }
    $r
}
function Write-Pol([string]$f, $entries) {
    New-Item -ItemType Directory -Force (Split-Path $f) | Out-Null
    $ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $ms; $u = [Text.Encoding]::Unicode
    $w.Write([byte[]](0x50, 0x52, 0x65, 0x67)); $w.Write([uint32]1)
    foreach ($e in $entries) {
        $w.Write($u.GetBytes("[$($e.Key)`0;$($e.Name)`0;")); $w.Write([uint32]$e.Type); $w.Write($u.GetBytes(';'))
        $w.Write([uint32]$e.Data.Length); $w.Write($u.GetBytes(';')); $w.Write([byte[]]$e.Data); $w.Write($u.GetBytes(']'))
    }
    $w.Flush(); [IO.File]::WriteAllBytes($f, $ms.ToArray())
}
function Sz([string]$k, [string]$n, [string]$v) { [pscustomobject]@{ Key = $k; Name = $n; Type = 1; Data = [Text.Encoding]::Unicode.GetBytes("$v`0") } }
$reg = '{35378EAC-683F-11D2-A89A-00C04FBBCFA2}'
function Gpt([string]$dir, [string]$machineExt, [string]$userExt, [int]$ver) {
    $t = "[General]`r`n"
    if ($machineExt) { $t += "gPCMachineExtensionNames=[$reg$machineExt]`r`n" }
    $t += "Version=$ver`r`n"
    if ($userExt) { $t += "gPCUserExtensionNames=[$reg$userExt]`r`n" }
    [IO.File]::WriteAllText("$dir\gpt.ini", $t, [Text.Encoding]::ASCII)
}

# 1. restricoes do Aluno (nao administradores)
$na = 'C:\Windows\System32\GroupPolicyUsers\S-1-5-32-545'
Write-Pol "$na\User\Registry.pol" @(Read-Pol "$old\User\Registry.pol")
Gpt $na '' '{D02B1F73-3407-48AE-BA88-E8213C6761F1}' 65536

# 2 e 3. politica geral: maquina (regras antigas) + papel de parede para todos
$gp = 'C:\Windows\System32\GroupPolicy'
Write-Pol "$gp\Machine\Registry.pol" @(Read-Pol "$old\Machine\Registry.pol")
$sys = 'Software\Microsoft\Windows\CurrentVersion\Policies\System'
Write-Pol "$gp\User\Registry.pol" @((Sz $sys 'Wallpaper' $img), (Sz $sys 'WallpaperStyle' '4'))   # 4 = preencher
Gpt $gp '{D02B1F72-3407-48AE-BA88-E8213C6761F1}' '{D02B1F73-3407-48AE-BA88-E8213C6761F1}' 65537

$csp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
New-Item $csp -Force | Out-Null
foreach ($p in 'Desktop', 'LockScreen') {
    Set-ItemProperty $csp "${p}ImagePath" $img
    Set-ItemProperty $csp "${p}ImageUrl" $img
    Set-ItemProperty $csp "${p}ImageStatus" 1 -Type DWord
}
& reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI' /v DisableLogonBackgroundImage /t REG_DWORD /d 0 /f | Out-Null

& gpupdate.exe /force | Out-Null
"Aluno (nao administradores): $((Read-Pol "$na\User\Registry.pol").Count) regras | todos: papel $img | maquina: $((Read-Pol "$gp\Machine\Registry.pol").Count) regras | arquivo: $(Test-Path $img)"
