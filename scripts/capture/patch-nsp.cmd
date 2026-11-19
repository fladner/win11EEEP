@echo off
rem Executado no WinPE (Shift+F10). Atualiza o install.wim ja capturado (disco CAPTURA) com:
rem   Windows\Setup\Scripts\SetupComplete.cmd (nova versao) e EEEP-RemoverNSP-NI.ps1 (aviso da LSA do NI mDNS),
rem   e libera leitura/execucao para Usuarios em Program Files\WinGet\Packages (CodeBlocks/SimulIDE).
rem 19/11: 1a rodada aplicou o icacls e o RemoverNSP, mas o copy do SetupComplete.cmd falhou (atributos) -> attrib antes.
set D=
for %%i in (C D E F G H I J K L M N O P Q R S T U V W) do if exist %%i:\install.wim if exist %%i:\captura.log set D=%%i
if "%D%"=="" (echo install.wim do disco CAPTURA nao encontrado & goto :eof)
set S=%~d0
echo install.wim em %D%:  scripts em %S%
echo Patch: %date% %time% > %D%:\patch2.log
if not exist %D%:\mnt mkdir %D%:\mnt
dism /English /Mount-Image /ImageFile:%D%:\install.wim /Index:1 /MountDir:%D%:\mnt >> %D%:\patch2.log
if errorlevel 1 (echo FALHA no mount & type %D%:\patch2.log & goto :eof)
set T=%D%:\mnt\Windows\Setup\Scripts
attrib %T%\SetupComplete.cmd >> %D%:\patch2.log
attrib -r -s -h %T%\SetupComplete.cmd >> %D%:\patch2.log 2>&1
copy /y %S%\SetupComplete.cmd %T%\SetupComplete.cmd >> %D%:\patch2.log 2>&1
copy /y %S%\EEEP-RemoverNSP-NI.ps1 %T%\EEEP-RemoverNSP-NI.ps1 >> %D%:\patch2.log 2>&1
find /c "RemoverNSP" %T%\SetupComplete.cmd >> %D%:\patch2.log
dir %T% >> %D%:\patch2.log
icacls "%D%:\mnt\Program Files\WinGet\Packages" /grant "*S-1-5-32-545:(OI)(CI)RX" /T /C /Q >> %D%:\patch2.log
echo icacls exit=%errorlevel% >> %D%:\patch2.log
dism /English /Unmount-Image /MountDir:%D%:\mnt /Commit /CheckIntegrity >> %D%:\patch2.log
echo commit exit=%errorlevel% >> %D%:\patch2.log
rd %D%:\mnt
echo Fim: %date% %time% >> %D%:\patch2.log
type %D%:\patch2.log
wpeutil shutdown
