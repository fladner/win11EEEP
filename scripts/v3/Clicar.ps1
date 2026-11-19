# Clique de mouse na sessao interativa da VM (o agente roda na sessao do Administrador).
# Uso dentro do job: . Clicar.ps1; Clicar 657 599   (coordenadas da tela da VM, iguais as da captura do VirtualBox)
Add-Type -Namespace EEEP -Name Mouse -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
[DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, System.UIntPtr e);
'@ -ErrorAction SilentlyContinue
function Clicar([int]$x, [int]$y, [switch]$Duplo) {
    [EEEP.Mouse]::SetCursorPos($x, $y) | Out-Null; Start-Sleep -Milliseconds 150
    $n = if ($Duplo) { 2 } else { 1 }
    for ($i = 0; $i -lt $n; $i++) {
        [EEEP.Mouse]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 60
        [EEEP.Mouse]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 120
    }
    "clique em $x,$y"
}
