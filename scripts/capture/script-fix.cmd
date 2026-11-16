@echo off
rem Executado no WinPE. Substitui C:\Windows\Setup\Scripts\EEEP-PrimeiroBoot.ps1 dentro do install.wim capturado.
set S=
for %%i in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do if exist %%i:\captura.log if exist %%i:\install.wim set S=%%i
if "%S%"=="" (echo disco da captura nao encontrado & goto :eof)
set F=%~d0
if not exist %F%\EEEP-PrimeiroBoot.ps1 (echo script novo nao encontrado em %F% & goto :eof)
echo Inicio: %date% %time% > %S%:\script-fix.log
if not exist %S%:\mnt md %S%:\mnt
dism /English /Mount-Image /ImageFile:%S%:\install.wim /Index:1 /MountDir:%S%:\mnt /LogPath:%S%:\dism-script.log
if errorlevel 1 (echo mount falhou >> %S%:\script-fix.log & goto fim)
rem o arquivo na imagem e somente leitura: sem o attrib o copy /y falha calado
attrib -r -s -h %S%:\mnt\Windows\Setup\Scripts\EEEP-PrimeiroBoot.ps1
del /f /q %S%:\mnt\Windows\Setup\Scripts\EEEP-PrimeiroBoot.ps1
copy /y %F%\EEEP-PrimeiroBoot.ps1 %S%:\mnt\Windows\Setup\Scripts\EEEP-PrimeiroBoot.ps1 >> %S%:\script-fix.log
find /c "function Parar" %S%:\mnt\Windows\Setup\Scripts\EEEP-PrimeiroBoot.ps1 >> %S%:\script-fix.log || (echo SCRIPT NAO TROCADO >> %S%:\script-fix.log & dism /English /Unmount-Image /MountDir:%S%:\mnt /Discard & goto fim)
dir %S%:\mnt\Windows\Setup\Scripts >> %S%:\script-fix.log
rem arquivo de resposta guardado pelo sysprep (usado no specialize/oobeSystem de cada instalacao)
if exist %S%:\mnt\Windows\Panther\unattend.xml copy /y %F%\unattend.xml %S%:\mnt\Windows\Panther\unattend.xml
if exist %S%:\mnt\Windows\System32\Sysprep\eeep-unattend.xml copy /y %F%\unattend.xml %S%:\mnt\Windows\System32\Sysprep\eeep-unattend.xml
dir %S%:\mnt\Windows\Panther >> %S%:\script-fix.log
dism /English /Unmount-Image /MountDir:%S%:\mnt /Commit /LogPath:%S%:\dism-script.log
echo commit exit=%errorlevel% >> %S%:\script-fix.log
:fim
echo Fim: %date% %time% >> %S%:\script-fix.log
wpeutil shutdown
