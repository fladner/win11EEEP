@echo off
rem Executado no WinPE (Shift+F10). Base 22/02/2025 (Windows 11 23H2) na VM EEEP-2025.
rem Disco 0 = Windows generalizado (300 GB). Disco de destino = captura2025.vdi (350 GB, vazio).
rem 1) confere que a imagem esta generalizada  2) coloca o Winre.wim da particao de recuperacao dentro
rem do Windows (sem ele o instalador falha com 0x80070003)  3) formata o destino  4) captura com DISM.
set WIN=
for %%i in (C D E F G H I J K L M N O P) do if exist %%i:\Windows\System32\config\SOFTWARE if exist %%i:\Users\Aluno set WIN=%%i
if "%WIN%"=="" (echo Windows da imagem nao encontrado & goto :eof)
echo Windows encontrado em %WIN%:
type %WIN%:\Windows\Setup\State\State.ini
find /c "IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE" %WIN%:\Windows\Setup\State\State.ini >nul || (echo IMAGEM NAO GENERALIZADA: abortado & goto :eof)

rem --- WinRE ---
rem (uma versao anterior deste script atribuia letras as particoes do disco 0 procurando o WinRE e acabou
rem tirando a letra da particao do Windows; a busca foi removida)
rem a ISO de 22/02/2025 nao tem WinRE (nem particao de recuperacao); o instalador dela instala assim mesmo
if not exist %WIN%:\Windows\System32\Recovery\Winre.wim echo AVISO: Winre.wim nao encontrado; capturando sem WinRE (como a ISO original)

:destino
rem seguranca: so formata o disco de 350 GB totalmente livre
(echo list disk) > X:\ld.txt
diskpart /s X:\ld.txt > X:\ld-out.txt
type X:\ld-out.txt
find /c "350 GB   350 GB" X:\ld-out.txt >nul || (echo disco vazio de 350 GB nao encontrado: abortado por seguranca & goto :eof)
set DD=
rem descobre qual numero de disco tem 350 GB pela linha "Disco N ... 350 GB"
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
dism /English /Capture-Image /ImageFile:W:\install.wim /CaptureDir:%WIN%:\ /Name:"Windows 11 Pro EEEP" /Description:"Windows 11 Pro EEEP (base 22/02/2025)" /Compress:fast /CheckIntegrity /LogPath:W:\dism-captura.log
echo dism exit=%errorlevel% >> W:\captura.log
echo Fim: %date% %time% >> W:\captura.log
dism /English /Get-ImageInfo /ImageFile:W:\install.wim >> W:\captura.log
wpeutil shutdown
