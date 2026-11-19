@echo off
rem Executado no WinPE (Shift+F10). v3 completa: VM EEEP-2025 atualizada para 26H2 e generalizada.
rem Disco 0 = Windows generalizado (300 GB). Destino = captura-v3full.vdi (350 GB, vazio).
set WIN=
for %%i in (C D E F G H I J K L M N O P) do if exist %%i:\Windows\System32\config\SOFTWARE if exist %%i:\Users\Aluno set WIN=%%i
if "%WIN%"=="" (echo Windows da imagem nao encontrado & goto :eof)
echo Windows encontrado em %WIN%:
type %WIN%:\Windows\Setup\State\State.ini
find /c "IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE" %WIN%:\Windows\Setup\State\State.ini >nul || (echo IMAGEM NAO GENERALIZADA: abortado & goto :eof)
if not exist %WIN%:\Windows\System32\Recovery\Winre.wim (echo Winre.wim AUSENTE em System32\Recovery: abortado & goto :eof)
rem Windows.old na imagem = instalador do 26H2 falha (CRelocateOS 0x800700B7) e o PC reinicia em looping
if exist %WIN%:\Windows.old rd /s /q %WIN%:\Windows.old
if exist %WIN%:\Windows.old (echo Windows.old NAO removido: abortado & goto :eof)
for %%d in ("$WINDOWS.~BT" "$Windows.~WS" "$WinREAgent") do if exist %WIN%:\%%~d rd /s /q %WIN%:\%%~d

(echo list disk) > X:\ld.txt
diskpart /s X:\ld.txt > X:\ld-out.txt
type X:\ld-out.txt
find /c "350 GB   350 GB" X:\ld-out.txt >nul || (echo disco vazio de 350 GB nao encontrado: abortado por seguranca & goto :eof)
set DD=
for /f "tokens=2" %%d in ('find "350 GB   350 GB" X:\ld-out.txt ^| find "Dis"') do set DD=%%d
if "%DD%"=="" (echo numero do disco de destino nao identificado & goto :eof)
if "%DD%"=="0" (echo destino nao pode ser o disco 0 & goto :eof)
echo disco de destino: %DD%
(echo select disk %DD%& echo clean& echo convert gpt& echo create partition primary& echo format fs=ntfs quick label=CAPTURA& echo assign letter=W) > X:\fmt.txt
diskpart /s X:\fmt.txt
if not exist W:\ (echo falha ao preparar o disco de destino & goto :eof)

echo Windows em %WIN%: > W:\captura.log
echo Inicio: %date% %time% >> W:\captura.log
dir /a %WIN%:\Windows\System32\Recovery >> W:\captura.log
dism /English /Capture-Image /ImageFile:W:\install.wim /CaptureDir:%WIN%:\ /Name:"Windows 11 Pro EEEP" /Description:"Windows 11 Pro EEEP v3 (26H2, programas completos)" /Compress:fast /CheckIntegrity /LogPath:W:\dism-captura.log
echo dism exit=%errorlevel% >> W:\captura.log
echo Fim: %date% %time% >> W:\captura.log
dism /English /Get-ImageInfo /ImageFile:W:\install.wim >> W:\captura.log
wpeutil shutdown
