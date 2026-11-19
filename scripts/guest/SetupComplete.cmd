@echo off
rem EEEP: roda como SYSTEM no fim da instalacao, antes do primeiro logon.
rem O OOBE do 26H2 cria a conta temporaria defaultuser0, liga o logon automatico nela e abre o "OOBE do usuario",
rem que fica parado em "Um momento...". As contas da escola ja existem, entao nada disso e necessario.
set L=%WINDIR%\Setup\Scripts\SetupComplete.log
echo %date% %time% inicio >> %L%
reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE /v LaunchUserOOBE /t REG_DWORD /d 0 /f >> %L% 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 0 /f >> %L% 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v SystemAutoLogon /t REG_DWORD /d 0 /f >> %L% 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /f >> %L% 2>&1
net user defaultuser0 /delete >> %L% 2>&1
if exist %SystemDrive%\Users\defaultuser0 rd /s /q %SystemDrive%\Users\defaultuser0
net user Administrador /active:yes >> %L% 2>&1
rem o sysprep troca o SID das contas locais, mas o registro pessoal (NTUSER.DAT) do Aluno/CREDE continua
rem liberado so para o SID antigo -> "Falha na entrada do servico Cliente da Politica de Grupo. Acesso negado."
if exist %WINDIR%\Setup\Scripts\EEEP-CorrigirPerfis.ps1 %WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File %WINDIR%\Setup\Scripts\EEEP-CorrigirPerfis.ps1 >> %L% 2>&1
rem NSP do NI mDNS (Multisim) bloqueado pela protecao da LSA do 26H2 -> aviso a cada logon; tira do catalogo Winsock
if exist %WINDIR%\Setup\Scripts\EEEP-RemoverNSP-NI.ps1 %WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File %WINDIR%\Setup\Scripts\EEEP-RemoverNSP-NI.ps1 >> %L% 2>&1
rem CodeBlocks/SimulIDE (WinGet portatil) em Program Files\WinGet\Packages: Usuarios precisam de leitura e execucao
if exist "%ProgramFiles%\WinGet\Packages" icacls "%ProgramFiles%\WinGet\Packages" /grant "*S-1-5-32-545:(OI)(CI)RX" /T /C /Q >> %L% 2>&1
echo %date% %time% fim >> %L%
