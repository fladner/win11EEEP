@echo off
rem Executado no WinPE. Troca o unattend (SkipMachineOOBE) e o setupcomplete.cmd dentro do install.wim capturado.
set S=
for %%i in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do if exist %%i:\captura.log if exist %%i:\install.wim set S=%%i
if "%S%"=="" (echo disco da captura nao encontrado & goto :eof)
set F=%~d0
if not exist %F%\SetupComplete.cmd (echo arquivos novos nao encontrados em %F% & goto :eof)
echo Inicio: %date% %time% > %S%:\oobe-fix.log
if not exist %S%:\mnt md %S%:\mnt
dism /English /Mount-Image /ImageFile:%S%:\install.wim /Index:1 /MountDir:%S%:\mnt /LogPath:%S%:\dism-oobe.log
if errorlevel 1 (echo mount falhou >> %S%:\oobe-fix.log & goto fim)
set D=%S%:\mnt\Windows
rem arquivos na imagem podem ser somente leitura: sem o attrib o copy /y falha calado
for %%f in (%D%\Setup\Scripts\setupcomplete.cmd %D%\Panther\unattend.xml %D%\System32\Sysprep\eeep-unattend.xml) do if exist %%f (attrib -r -s -h %%f & del /f /q %%f)
copy /y %F%\SetupComplete.cmd %D%\Setup\Scripts\SetupComplete.cmd >> %S%:\oobe-fix.log
copy /y %F%\unattend.xml %D%\Panther\unattend.xml >> %S%:\oobe-fix.log
copy /y %F%\unattend.xml %D%\System32\Sysprep\eeep-unattend.xml >> %S%:\oobe-fix.log
set OK=1
find /c "defaultuser0" %D%\Setup\Scripts\SetupComplete.cmd >> %S%:\oobe-fix.log || set OK=0
find /c "SkipMachineOOBE" %D%\Panther\unattend.xml >> %S%:\oobe-fix.log || set OK=0
find /c "function Parar" %D%\Setup\Scripts\EEEP-PrimeiroBoot.ps1 >> %S%:\oobe-fix.log || set OK=0
if "%OK%"=="0" (echo ARQUIVOS NAO TROCADOS >> %S%:\oobe-fix.log & dism /English /Unmount-Image /MountDir:%S%:\mnt /Discard & goto fim)
dir %D%\Setup\Scripts %D%\Panther\unattend.xml >> %S%:\oobe-fix.log
dism /English /Unmount-Image /MountDir:%S%:\mnt /Commit /LogPath:%S%:\dism-oobe.log
echo commit exit=%errorlevel% >> %S%:\oobe-fix.log
:fim
echo Fim: %date% %time% >> %S%:\oobe-fix.log
wpeutil shutdown
