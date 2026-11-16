# Abre o instalador do Nmap (com janela; a versao gratuita nao instala em silencio) e confere o PATH do Python.
$mp = [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';'
"Python314 no PATH da maquina: $(@($mp | Where-Object { $_ -like '*Python314*' }).Count -gt 0)"
if (-not ($mp | Where-Object { $_ -like '*Python314*' })) {
    [Environment]::SetEnvironmentVariable('Path', ((@('C:\Program Files\Python314\Scripts\', 'C:\Program Files\Python314\') + $mp) -join ';'), 'Machine'); 'PATH += Python314'
}
$src = (Get-ChildItem 'D:\kit\Pacotes\Nmap' -Filter 'nmap-*-setup.exe' | Select-Object -First 1).FullName
Copy-Item $src "$env:TEMP\nmap-setup.exe" -Force
Start-Process "$env:TEMP\nmap-setup.exe"
'instalador do Nmap aberto na sessao do Administrador'
