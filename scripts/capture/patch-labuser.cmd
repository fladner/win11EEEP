@echo off
rem Executado no WinPE (Shift+F10). Devolve ao install.wim o Configure-LabUser.ps1 do kit
rem (C:\ProgramData\LabSetup\UserConfig), chamado no logon pela chave Run LabSetupConfigurarUsuario.
rem O 60-limpeza tinha apagado C:\ProgramData\LabSetup inteiro -> PowerShell com erro a cada logon e sem Lab-Templates.
set D=
for %%i in (C D E F G H I J K L M N O P Q R S T U V W) do if exist %%i:\install.wim if exist %%i:\captura.log set D=%%i
if "%D%"=="" (echo install.wim do disco CAPTURA nao encontrado & goto :eof)
set S=%~d0
echo install.wim em %D%:  scripts em %S%
echo Patch LabUser: %date% %time% > %D%:\patch3.log
if not exist %D%:\mnt mkdir %D%:\mnt
dism /English /Mount-Image /ImageFile:%D%:\install.wim /Index:1 /MountDir:%D%:\mnt >> %D%:\patch3.log
if errorlevel 1 (echo FALHA no mount & type %D%:\patch3.log & goto :eof)
set U=%D%:\mnt\ProgramData\LabSetup\UserConfig
if not exist %U% mkdir %U%
copy /y %S%\Configure-LabUser.ps1 %U%\Configure-LabUser.ps1 >> %D%:\patch3.log 2>&1
dir %U% >> %D%:\patch3.log
dir "%D%:\mnt\Users\Public\Documents\Lab-Templates" >> %D%:\patch3.log 2>&1
rem conferencia do patch anterior
find /c "RemoverNSP" %D%:\mnt\Windows\Setup\Scripts\SetupComplete.cmd >> %D%:\patch3.log
dism /English /Unmount-Image /MountDir:%D%:\mnt /Commit /CheckIntegrity >> %D%:\patch3.log
echo commit exit=%errorlevel% >> %D%:\patch3.log
rd %D%:\mnt
echo Fim: %date% %time% >> %D%:\patch3.log
type %D%:\patch3.log
wpeutil shutdown
