@echo off
rem Executado no WinPE. Coloca o Winre.wim oficial do 26H2 dentro do install.wim capturado.
rem Na maquina de origem o WinRE fica na particao de recuperacao, entao a captura nao o inclui, e o
rem instalador do 26H2 falha (0x80070003) ao extrair \Windows\System32\Recovery\winre.wim.
set S=
for %%i in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do if exist %%i:\captura.log if exist %%i:\install.wim set S=%%i
if "%S%"=="" (echo disco da captura nao encontrado & goto :eof)
set F=%~d0
if not exist %F%\Winre.wim (echo Winre.wim nao encontrado em %F% & goto :eof)
echo Inicio: %date% %time% > %S%:\winre-fix.log
if not exist %S%:\mnt md %S%:\mnt
dism /English /Mount-Image /ImageFile:%S%:\install.wim /Index:1 /MountDir:%S%:\mnt /LogPath:%S%:\dism-winre.log
if errorlevel 1 (echo mount falhou >> %S%:\winre-fix.log & goto fim)
if not exist %S%:\mnt\Windows\System32\Recovery md %S%:\mnt\Windows\System32\Recovery
copy /y %F%\Winre.wim %S%:\mnt\Windows\System32\Recovery\Winre.wim
attrib +h +s %S%:\mnt\Windows\System32\Recovery\Winre.wim
dir /a %S%:\mnt\Windows\System32\Recovery >> %S%:\winre-fix.log
dism /English /Unmount-Image /MountDir:%S%:\mnt /Commit /CheckIntegrity /LogPath:%S%:\dism-winre.log
echo commit exit=%errorlevel% >> %S%:\winre-fix.log
:fim
echo Fim: %date% %time% >> %S%:\winre-fix.log
dism /English /Get-ImageInfo /ImageFile:%S%:\install.wim /Index:1 >> %S%:\winre-fix.log
wpeutil shutdown
