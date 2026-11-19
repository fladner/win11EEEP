@echo off
rem Executado no WinPE (Shift+F10). v3 (26H2 limpo) na VM EEEP-v3.
rem Disco 0 = Windows generalizado (100 GB). Destino = captura-v3.vdi (64 GB, vazio).
set WIN=
for %%i in (C D E F G H I J K L M N O P) do if exist %%i:\Windows\System32\config\SOFTWARE if exist %%i:\v3min.log set WIN=%%i
if "%WIN%"=="" (echo Windows da imagem nao encontrado & goto :eof)
echo Windows encontrado em %WIN%:
type %WIN%:\Windows\Setup\State\State.ini
find /c "IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE" %WIN%:\Windows\Setup\State\State.ini >nul || (echo IMAGEM NAO GENERALIZADA: abortado & goto :eof)
if not exist %WIN%:\Windows\System32\Recovery\Winre.wim (echo Winre.wim AUSENTE em System32\Recovery: abortado & goto :eof)
rem O instalador do 26H2 aplica a imagem em $WINDOWS.~BT\NewOS e depois move tudo para C:\. Se a imagem tiver
rem Windows.old, a mudanca falha (CRelocateOS 0x800700B7), a instalacao aborta e o PC reinicia em looping.
if exist %WIN%:\Windows.old rd /s /q %WIN%:\Windows.old
if exist %WIN%:\Windows.old (echo Windows.old NAO removido: abortado & goto :eof)
for %%d in ("$WINDOWS.~BT" "$Windows.~WS" "$WinREAgent") do if exist %WIN%:\%%~d rd /s /q %WIN%:\%%~d

rem seguranca: so formata o disco de 64 GB totalmente livre
(echo list disk) > X:\ld.txt
diskpart /s X:\ld.txt > X:\ld-out.txt
type X:\ld-out.txt
find /c "64 GB    64 GB" X:\ld-out.txt >nul || (echo disco vazio de 64 GB nao encontrado: abortado por seguranca & goto :eof)
set DD=
for /f "tokens=2" %%d in ('find "64 GB    64 GB" X:\ld-out.txt ^| find "Dis"') do set DD=%%d
if "%DD%"=="" (echo numero do disco de destino nao identificado & goto :eof)
if "%DD%"=="0" (echo destino nao pode ser o disco 0 & goto :eof)
echo disco de destino: %DD%
(echo select disk %DD%& echo clean& echo convert gpt& echo create partition primary& echo format fs=ntfs quick label=CAPTURA& echo assign letter=W) > X:\fmt.txt
diskpart /s X:\fmt.txt
if not exist W:\ (echo falha ao preparar o disco de destino & goto :eof)

echo Windows em %WIN%: > W:\captura.log
echo Inicio: %date% %time% >> W:\captura.log
type %WIN%:\v3min.log >> W:\captura.log
dir /a %WIN%:\Windows\System32\Recovery >> W:\captura.log
dism /English /Capture-Image /ImageFile:W:\install.wim /CaptureDir:%WIN%:\ /Name:"Windows 11 Pro EEEP" /Description:"Windows 11 Pro EEEP v3 minima (26H2 limpo)" /Compress:max /CheckIntegrity /LogPath:W:\dism-captura.log
echo dism exit=%errorlevel% >> W:\captura.log
echo Fim: %date% %time% >> W:\captura.log
dism /English /Get-ImageInfo /ImageFile:W:\install.wim >> W:\captura.log
wpeutil shutdown
