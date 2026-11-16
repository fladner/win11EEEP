# Envia teclas (scancodes set 1) para a VM e captura a tela.
# Uso: vmkeys.ps1 -Keys 'alt+n','enter','wait:5','tab' -Shot nome
param(
    [string[]]$Keys = @(),
    [string]$Shot,
    [int]$After = 3,
    [string]$VM = 'EEEP-26H2',
    [string]$OutDir = "$env:TEMP\claude\ba751ffd55063bf2\8fe12f81-1fc1-4eeb-9ad1-e3c278635bca\scratchpad"
)
$vb = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
$map = @{
    'esc'=0x01;'1'=0x02;'2'=0x03;'3'=0x04;'4'=0x05;'5'=0x06;'6'=0x07;'7'=0x08;'8'=0x09;'9'=0x0a;'0'=0x0b
    'backspace'=0x0e;'tab'=0x0f;'q'=0x10;'w'=0x11;'e'=0x12;'r'=0x13;'t'=0x14;'y'=0x15;'u'=0x16;'i'=0x17;'o'=0x18;'p'=0x19
    'enter'=0x1c;'ctrl'=0x1d;'a'=0x1e;'s'=0x1f;'d'=0x20;'f'=0x21;'g'=0x22;'h'=0x23;'j'=0x24;'k'=0x25;'l'=0x26
    'shift'=0x2a;'z'=0x2c;'x'=0x2d;'c'=0x2e;'v'=0x2f;'b'=0x30;'n'=0x31;'m'=0x32;'alt'=0x38;'space'=0x39
    'dot'=0x34;'semi'=0x35;'bslash'=0x56;'minus'=0x0c;'slash'=0x73;'equal'=0x0d;'tilde'=0x28
    'f1'=0x3b;'f2'=0x3c;'f3'=0x3d;'f4'=0x3e;'f5'=0x3f;'f6'=0x40;'f7'=0x41;'f8'=0x42;'f9'=0x43;'f10'=0x44
}
$ext = @{ 'up'=0x48;'down'=0x50;'left'=0x4b;'right'=0x4d;'del'=0x53;'home'=0x47;'end'=0x4f;'win'=0x5b }
function Codes([string]$k, [bool]$release) {
    if ($ext.ContainsKey($k)) { $c = $ext[$k]; if ($release) { $c = $c -bor 0x80 }; return @('e0', ('{0:x2}' -f $c)) }
    if (-not $map.ContainsKey($k)) { throw "tecla desconhecida: $k" }
    $c = $map[$k]; if ($release) { $c = $c -bor 0x80 }; return @('{0:x2}' -f $c)
}
$Keys = @($Keys | ForEach-Object { $_.Split(',') } | Where-Object { $_ })
# "text:<frase>" digita texto simples (layout ABNT2): letras minusculas, digitos, espaco - . : \
$Keys = @($Keys | ForEach-Object {
    if ($_ -like 'text:*') {
        foreach ($ch in $_.Substring(5).ToCharArray()) {
            switch -CaseSensitive ($ch) {
                ' '  { 'space' } '-' { 'minus' } '.' { 'dot' } ':' { 'shift+semi' } '\' { 'bslash' } '/' { 'slash' } '?' { 'shift+slash' } '=' { 'equal' } ';' { 'semi' }
                '(' { 'shift+9' } ')' { 'shift+0' } '$' { 'shift+4' } '%' { 'shift+5' } '*' { 'shift+8' } '>' { 'shift+dot' } '|' { 'shift+bslash' } '~' { 'tilde'; 'space' }
                default { if ([char]::IsUpper($ch)) { "shift+$([char]::ToLower($ch))" } else { [string]$ch } }
            }
        }
    } else { $_ }
})
foreach ($combo in $Keys) {
    if ($combo -match '^wait:(\d+)$') { Start-Sleep -Seconds ([int]$Matches[1]); continue }
    $parts = $combo.ToLower().Split('+')
    $seq = @()
    foreach ($p in $parts) { $seq += Codes $p $false }
    [array]::Reverse($parts)
    foreach ($p in $parts) { $seq += Codes $p $true }
    & $vb controlvm $VM keyboardputscancode @seq
    Start-Sleep -Milliseconds 400
}
if ($Shot) {
    Start-Sleep -Seconds $After
    $f = Join-Path $OutDir "$Shot.png"
    & $vb controlvm $VM screenshotpng $f
    $f
}
