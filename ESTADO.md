# ISO EEEP 26H2 — estado do build (atualizado em 15/11/2026, ~16:50)

## Como funciona
- VM VirtualBox `EEEP-26H2` em `C:\win11EEEP\vm` (snapshot `base-25H2-instalada`). Disco 220 GB.
- Host -> VM: `scripts\host\Servidor-Comandos.ps1` (fila em 127.0.0.1:8765, precisa estar rodando) e
  `scripts\host\Run-Guest.ps1 -Agent sys|user -File <script>` para executar scripts dentro da VM.
- Agentes na VM: tarefas agendadas `EEEPBuild-sys` (SYSTEM, no boot) e `EEEPBuild-user` (Administrador, no logon),
  arquivos em `C:\ProgramData\EEEPBuild`. Remover antes da captura.
- Kit, scripts e Revit entram na VM como DVD (`build\kit.viso`, unidade D:).
- Reinicios: a VM pode travar em tela preta ao reiniciar; `scripts\host\Vigia-Reinicio.ps1` reseta sozinho.
- Live snapshot trava (Hyper-V ativo no host): snapshot so com a VM desligada.

## Feito
- ISO original instalada na VM; Windows atualizado para 26H2 (26300.9974).
- Removidos: PostgreSQL 17, SketchUp 8, DAEMON Tools Lite, Adobe Acrobat (64-bit).
- Atualizados pelo winget (20 pacotes) — `scripts\jobs\20-atualizar-programas.ps1`.
- Avisos de OOBE/conta Microsoft/backup/OneDrive desativados — `scripts\guest\Desativar-AvisosOOBE.ps1`.
- Kit instalado direto (`jobs\30`): JDK 21, Maven, Eclipse, NetBeans 25, Android Studio, Android SDK (C:\Android),
  Flutter (C:\Dev\flutter), Packet Tracer 9.0.1, agente VDE-CE (nao executar), atalho Figma, modelos.
- XAMPP 8.2.12 com Apache e MariaDB como servicos automaticos (`jobs\31`), http://localhost OK.

- Revit 2026 removido e Revit 2027 (27.0.4.412) instalado (`jobs\40`).

## PONTO DE RETOMADA ATUAL (16/11 ~09:50) — v2 GERADA, EM TESTE
- v2: C:\win11EEEP\Win11Pro_26H2_EEEP_v2.iso (68,94 GB), SHA256
  22FE6F16DE224926DCB7FAAE8B73FA3B7691CDBB9882B09FEDDF74FEEE954459. Tem Winre.wim, EEEP-PrimeiroBoot.ps1 corrigido
  (sc.exe + taskkill) e unattend com `net user Administrador /active:yes` como Order 1 (conferidos dentro do wim).
- Corrigida no WinPE com scripts\capture\script-fix.cmd (16 GB de RAM na VM; 4 GB da erro 0x80070008 no mount).
- Instalacao de teste na VM EEEP-Teste iniciada ~09:45. Depois de aprovada: enviar ao Google Drive do usuario
  (metodo a escolher) e apagar a v1.

## PONTO DE RETOMADA ANTERIOR (16/11 ~03:30) — ISO v1 GERADA
- Captura ok (dism exit=0). 1a ISO falhou na instalacao (0x80070003: faltava Windows\System32\Recovery\Winre.wim).
  Corrigido com scripts\capture\winre-fix.cmd (Winre.wim oficial inserido no install.wim do captura.vdi, commit ok).
- ISO final: C:\win11EEEP\Win11Pro_26H2_EEEP.iso (68,75 GB), SHA256 2B5F5A5FCA30FE1A0FC2D1552ED08338E57F6F92569A64C1DBA8AA449DB95FD7.
- Teste na VM EEEP-Teste (scripts\host\Criar-VM-Teste.ps1) em andamento; usuario precisa da ISO pronta as 06:00 de 16/11.
- Plano B se o setup novo falhar: link "Versao anterior da instalacao" na tela de opcoes do instalador.
- ~04:40: a copia da imagem terminou, mas no specialize o EEEP-PrimeiroBoot.ps1 TRAVA em Stop-Service AnyDesk
  ("Aguardando que o servico AnyDesk seja parado..."). Contorno manual: Shift+F10 e `taskkill /f /im AnyDesk.exe`
  (e `taskkill /f /im rustdesk.exe`). Script corrigido no repo (sc.exe + taskkill, sem esperar). Para corrigir a ISO:
  VM com WinPE + captura.vdi + build\script.viso -> fix.cmd (scripts\capture\script-fix.cmd), depois
  `Montar-ISO.ps1 -ReusarInstalador`.
- ~04:45: instalacao de teste passou do specialize e chegou ao OOBE ("Um momento..."). VM EEEP-26H2 ligada (4 GB RAM)
  no Boot Manager do firmware com SATA1 = ISO oficial, SATA2 = captura.vdi, SATA3 = build\script.viso: escolher
  "UEFI VBOX CD-ROM VB1", espaco, Shift+F10 e `for %i in (C D E F G H I J) do if exist %i:\fix.cmd %i:\fix.cmd`.
  Interrompido porque a verificacao automatica de comandos do Claude parou de responder.

## PONTO DE RETOMADA ANTERIOR (15/11 ~21:20) — SYSPREP FEITO, FALTA CAPTURAR
- Tudo instalado e testado como Aluno (usuario confirmou). AutoCAD 2027 oficial 26.0.60, Revit 2027, XAMPP 8.2 reinstalado
  (servicos ok), PostgreSQL 18 ok, limpeza feita. Hipervisor do host DESLIGADO (bcdedit off): religar com `auto` no fim.
- Snapshots: `pre-sysprep` (tudo pronto, antes de generalizar) e `pos-sysprep` (generalizado). NAO dar boot pelo disco.
- VM configurada para captura (`scripts\host\Iniciar-Captura.ps1`): SATA1 = ISO oficial, SATA2 = vm\captura\captura.vdi
  (300 GB vazio), SATA3 = build\cap.viso (cap.cmd), rede desligada. O EFI insiste no Windows Boot Manager do disco:
  ligar a VM pressionando Esc -> Boot Manager -> "UEFI VBOX CD-ROM VB1" -> espaco ("pressione qualquer tecla").
- No WinPE (tela do instalador): Shift+F10, descobrir a letra do DVD EEEPCAP e rodar `<letra>:\cap.cmd`
  (formata o Disco 1 de 300 GB, captura com dism para W:\install.wim e desliga).
- Depois: `scripts\host\Montar-ISO.ps1` (7-Zip extrai install.wim do captura.vdi, junta com a ISO oficial + ei.cfg,
  oscdimg -> C:\win11EEEP\Win11Pro_26H2_EEEP.iso).
- Teste: VM nova com a ISO final; conferir contas, GPOs, idioma (pacote LXP pt-BR foi removido p/ sysprep),
  IDs diferentes de AnyDesk/RustDesk, servicos, ausencia de avisos. Depois commit dos scripts no GitHub.
- O servidor de comandos (Servidor-Comandos.ps1) so e necessario se precisar voltar ao snapshot pre-sysprep.

## PONTO DE RETOMADA ANTERIOR (15/11 ~19:10, ja concluido): VM desligada para o usuario desativar o hipervisor do host e reiniciar o PC
Depois do reinicio do host:
1. Iniciar o servidor de comandos em segundo plano: `scripts\host\Servidor-Comandos.ps1`.
2. Ligar a VM: `VBoxManage startvm EEEP-26H2 --type gui` (conferir no VBox.log que nao aparece mais "NEM"/Hyper-V).
   O agente sys conecta sozinho; o usuario precisa entrar como Administrador para o agente user.
3. Rodar `jobs\24-remover-duplicados.ps1` (agente sys): duplicados Arduino 2.0.3 / LibreCAD 2.2.0 / NetBeans 16,
   Arduino 2.3.11 para todos (ALLUSERS=1), JDK 21 + JAVA_HOME (falhou com 1618), Android Studio (falhou com 1223).
4. PostgreSQL 18: instalacao parcial (arquivos em C:\Program Files\PostgreSQL\18, sem data/servico). Remover o resto
   e reinstalar em modo unattended (optionfile com superpassword informada pelo usuario no chat; nao gravar no repo),
   conferir servico, porta 5432 e login.
5. Seguir a lista "Falta" abaixo. NAO rodar instalacoes MSI em paralelo (erro 1618).

## Logs na VM: C:\ProgramData\EEEPBuild\kit.log e programas.log

## Falta
1. `jobs\22-segunda-passada.ps1`: Inkscape 1.4, GIMP 3.2, FreeCAD 1.1, Python 3.14 (remove 3.11).
2. Opcional: Anaconda 2026.07, SimulIDE 1.1.0, Fusion 360 (Fusion Admin Install.exe --globalinstall), Nmap (instalador com cliques).
3. Postman e extensoes do VS Code (vscjava.vscode-java-pack, vmware.vscode-boot-dev-pack, Dart-Code.flutter,
   Postman.postman-for-vscode) nos perfis Administrador e Aluno; remover C:\Users\Aluno\flutter antigo e o PATH dele.
4. Residuos: drivers dtlitescsibus/dtliteusbbus do DAEMON Tools; atalhos quebrados.
5. Limpeza: temporarios, instaladores, cache do Windows Update, `dism /online /cleanup-image /startcomponentcleanup`.
6. AnyDesk e RustDesk: parar servicos e remover so ID/chaves (preservar senha e servidor do RustDesk), com a rede da VM desligada.
7. Remover agentes de build. Desligar a VM e tirar snapshot. Sysprep /generalize /oobe /shutdown com unattend que
   mantem Administrador (conta interna, reativar), Aluno e CREDE (desativada) e pula o OOBE. Se o sysprep falhar,
   voltar ao snapshot e capturar sem generalizar (como a ISO original).
8. Captura: boot da VM pelo WinPE da ISO oficial, `dism /capture-image` para um segundo disco virtual; extrair o
   install.wim no host com 7-Zip.
9. Montagem: conteudo de `Windows11_Client_x64_pt-br_26300_9457.iso` + nosso `sources\install.wim` + `sources\ei.cfg`
   (Professional/Retail); gerar com oscdimg (UDF, boot BIOS+UEFI).
10. Teste: instalar a ISO nova em VM limpa; conferir usuarios, GPOs, programas, servicos do XAMPP, IDs diferentes
    do AnyDesk/RustDesk em duas instalacoes, ausencia dos avisos.
11. Publicar scripts no GitHub (https://github.com/fladner/win11EEEP) — ainda nao foi feito nenhum commit.

## Decisoes do usuario
- Usuarios mantidos como estao; ISO instalavel em qualquer PC compativel; sem limite de tamanho.
- Sem AppLocker por enquanto. MySQL Server fica no 8.0. Dev-C++ fica no 4.9.9.2. RustDesk ja atualizado pelo usuario.
- Licencas dos programas: usuario autorizou aceite automatico. Senha do postgres informada pelo usuario (nao registrar).
