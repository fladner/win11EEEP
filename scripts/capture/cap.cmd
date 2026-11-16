@echo off
rem Executado no WinPE (Shift+F10 na tela do instalador). Formata o disco vazio de destino (300 GB,
rem porta SATA 2 = Disco 1), localiza a particao do Windows generalizado e captura a imagem.
rem ATENCAO: o WinRE da origem fica na particao de recuperacao e nao entra na captura. Depois desta etapa,
rem rode winre-fix.cmd (ou faca "reagentc /disable" antes do sysprep) para incluir o Winre.wim na imagem.
set WIN=
for %%i in (C D E F G H I J K L M N O P) do if exist %%i:\Windows\System32\config\SOFTWARE if exist %%i:\Users\Aluno set WIN=%%i
if "%WIN%"=="" (echo Windows da imagem nao encontrado & goto :eof)
echo Windows encontrado em %WIN%:

rem seguranca: so formata o Disco 1 se ele tiver 300 GB (o disco do Windows tem 220 GB)
(echo list disk) > X:\ld.txt
diskpart /s X:\ld.txt > X:\ld-out.txt
type X:\ld-out.txt
rem o WinPE do 26H2 nao tem findstr; a conferencia usa find (Disco 1 com 300 GB e 300 GB livres)
find /c "300 GB   300 GB" X:\ld-out.txt >nul || (echo Disco 1 nao e o disco vazio de 300 GB: abortado por seguranca & goto :eof)
(echo select disk 1& echo clean& echo convert gpt& echo create partition primary& echo format fs=ntfs quick label=CAPTURA& echo assign letter=W) > X:\fmt.txt
diskpart /s X:\fmt.txt
if not exist W:\ (echo falha ao preparar o disco de destino & goto :eof)

echo Windows em %WIN%: > W:\captura.log
echo Inicio: %date% %time% >> W:\captura.log
dism /English /Capture-Image /ImageFile:W:\install.wim /CaptureDir:%WIN%:\ /Name:"Windows 11 Pro EEEP" /Description:"Windows 11 Pro 26H2 EEEP" /Compress:fast /CheckIntegrity /LogPath:W:\dism-captura.log
echo dism exit=%errorlevel% >> W:\captura.log
echo Fim: %date% %time% >> W:\captura.log
dism /English /Get-ImageInfo /ImageFile:W:\install.wim >> W:\captura.log
wpeutil shutdown
