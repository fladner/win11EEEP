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

## NOVO PLANO (16/11 tarde) — v3 26H2 SUSPENSA, BASE NOVA = ISO ANTIGA DO USUARIO
- A v1 26H2 entrou em looping de reinicio num Positivo real (NVMe, i3-10100T). O usuario trara hoje a noite uma ISO
  Windows 11 mais antiga, que funciona em qualquer PC, com menos programas e a senha antiga do Administrador.
- Gerar DUAS ISOs a partir dela:
  1. Mesma versao do Windows (sem atualizacao de versao) + todos os programas de PROGRAMAS.md.
  2. Depois, tudo atualizado (Windows inclusive).
- Trocar a senha do Administrador pela atual: o USUARIO digita na VM (Claude nao digita senhas).
- Docker Desktop (WSL2/hipervisor): SOMENTE na versao 2 (decisao do usuario, 16/11). Node.js LTS e IntelliJ IDEA
  Community entram nas duas (jobs\54).
- VM de build: EEEP-2025 (vm\eeep2025, NAT com localhost-reachable ligado, kit.viso como D:), snapshot
  base-2025-instalada. Sequencia: scripts\host\Sequencia-2025.ps1. PostgreSQL 18: jobs\55 (senha digitada na VM).
- Kali Linux fica FORA (decisao do usuario, 16/11). VisuAlg: jobs\56 (ja aplicado na VM).
- Faltam instaladores (usuario vai buscar): Solid Edge 2026, SinuTrain, Multisim 14.3, PSIM Demo, Proteus 9 Demo.
- v3 26H2 (D:\EEEP\Win11Pro_26H2_EEEP_v3.iso, SHA256 D4E53E6A...9FA5) tem a correcao do defaultuser0, mas o teste
  ficou suspenso (VM EEEP-Teste com estado salvo, disco SATA). O VirtualBox nao emula NVMe para o WinPE 26100
  (stornvme codigo 10, 0xC000000D), entao o caso do Positivo nao foi reproduzido.

## PONTO DE RETOMADA ANTERIOR (16/11 ~09:50) — v2 GERADA, EM TESTE
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
- VM EEEP-2025: DNS fixo 8.8.8.8/1.1.1.1 no adaptador Ethernet (o DNS repassado pelo NAT parou). ANTES DO SYSPREP: Set-DnsClientServerAddress -InterfaceAlias Ethernet -ResetServerAddresses.

- 17/11: a v3 26H2 tambem falhou no PC real (usuario testou). Apagados com autorizacao: VM EEEP-26H2, build\iso, build\winre, v3.iso. A versao 1 usa o INSTALADOR da ISO de 22/02/2025 (F:\EEEP\iso2025) + install.wim capturado (vm\captura\captura2025.vdi); saida G:\EEEP\Win11Pro_EEEP_v1.iso. Snapshots da EEEP-2025: pre-sysprep-v1 (ponto de partida da versao 2) e pos-sysprep-v1.
- 17/11 madrugada: v1 TESTADA em VM limpa (EEEP-Teste, UEFI+TPM+SecureBoot): 2 resets normais, sem looping, sem OOBE, login com Administrador e Aluno (CREDE oculto); EEEP-PrimeiroBoot.log e SetupComplete.log OK; AnyDesk gerou service.conf novo; AnyDesk/RustDesk/PG18/Apache automaticos. Login nas contas: falta o usuario testar (tem senha).
- 17/11 manha: v2 em andamento. Partiu de pre-sysprep-v1 (que ja estava no build 22631.6199 = ultima cumulativa do 23H2, fim do suporte). Job 90: winget upgrade (Autodesk Access, IntelliJ 2026.3, HelpPack LibreOffice, Firefox 160, MySQL Workbench 26.10, Python Launcher; fora: Orwell Dev-C++, NI Package Manager), recursos WSL/VMP, WSL 3.0.5 (MSI oficial; o winget instalou so para o SYSTEM), Docker Desktop (servico automatico, Aluno em docker-users, atalho na area de trabalho publica). Defender/MSRT atualizados. Snapshot v2-programas-23H2. PENDENTE: usuario decidir se a v2 sobe de versao (24H2/25H2, risco do mesmo looping do 26H2) ou fica no 23H2.
- 17/11: v1 funcionou perfeitamente no Positivo (confirmado pelo usuario). v2 fica no 23H2 (usuario: "Siga").
- 17/11: Google Earth Pro adicionado SO na v2 (job 90). Snapshots: v2-programas-23H2 -> v2-com-earth (Earth + job 70; ponto de partida para novos programas) -> pos-sysprep-v2-earth. pos-sysprep-v2 (sem Earth) esta obsoleto. Captura: vm\captura\captura2025-v2.vdi.
- 17/11: ISO v2 = C:\win11EEEP\Win11Pro_EEEP_v2.iso (65,12 GB) SHA256 79F51115435FBE09B66A3C10BEFC5227DCFF692286F24374B284E14EF2B0C18C. TESTADA em VM limpa: 2 resets normais, sem looping, sem OOBE, login com Administrador e Aluno, PrimeiroBoot.log e SetupComplete.log OK (erros de defaultuser0/DefaultUserName ausentes sao esperados). Falta o usuario testar no Positivo: login do Aluno e "docker run hello-world" (VT-x ligado na BIOS).
- Aviso: scripts\host\Criar-VM-Teste.ps1 usa ErrorActionPreference=Stop e aborta no createmedium (progresso no stderr); terminei a VM a mao. Corrigir.
- 17/11: usuario decidiu: Google Earth so na v2; v1 fica como esta.
- 17/11: v2 TESTADA pelo usuario em notebook real (o mesmo que dava looping com as versoes 26H2 descartadas): instalou OK, docker run hello-world OK. Proximo: v3 = 25H2 final (usuario ja testou 25H2 original no Positivo e funciona) pelo mesmo processo em VM.

## 17/11 noite — CAUSA DO LOOPING DO 26H2 ENCONTRADA
- O instalador do 26H2 (build 26300) aplica a imagem em C:\$WINDOWS.~BT\NewOS e depois move para C:\. Se o install.wim tem
  a pasta Windows.old, falha com "CRelocateOS ... Windows.old ... 0x800700B7", mostra "Falha na instalacao do Windows 11"
  e o PC reinicia em looping. As builds 26H2 antigas vinham de upgrade 25H2->26H2 (Windows.old cheia). 23H2 usa o
  instalador antigo, sem essa mudanca. Correcao: scripts\capture\capv3.cmd e scripts\v3\v3min.ps1 removem Windows.old,
  $WINDOWS.~BT e $Windows.~WS antes de capturar/generalizar.
- v3 minima (26H2 limpo, sem programas, Aluno/Administrador SEM SENHA = so teste): D:\EEEP\Win11Pro_EEEP_v3min.iso
  SHA256 D5AC05BF6377FC0F50C9AD8C1CE4464F28BE738F202E5D2CFEA9A1C6EC38699F. Testada em VM limpa: 2 resets, sem OOBE, login OK.
  VM de build: EEEP-v3 (D:\EEEP\vm, autounattend em modo auditoria: scripts\v3\autounattend.xml + v3min.ps1).
- GPO/papel: scripts\v3\Aplicar-GPO-Papel.ps1 (+ scripts\v3\gpo extraido da v2). Restricoes do Aluno -> politica de
  "Nao administradores" (GroupPolicyUsers\S-1-5-32-545); papel C:\wallpaper.png para todos (politica geral) + tela de
  bloqueio/login (PersonalizationCSP). Testado na VM: papel no bloqueio, login e Aluno; personalizacao bloqueada no Aluno.
- Decisao do usuario: v3 completa = UPGRADE da VM EEEP-2025 (snapshot v2-com-earth, 23H2 com todos os programas, inclusive
  Adobe CS5.5) para 26H2, limpar Windows.old e a chave HKLM\SYSTEM\Setup\Upgrade, aplicar GPO/papel, sysprep, captura.
  Upgrade iniciado ~21:20 (setup.exe /auto upgrade /quiet /dynamicupdate disable). NAO usar o disco H: (pedido do usuario).
- Inventario completo da v3 (caso precise reinstalar do zero): INVENTARIO-V3.md.

## 18/11/2026 - v3 completa (26H2): ISO e testes
- ISO: D:\EEEP\Win11Pro_EEEP_v3.iso, 66,7 GB, SHA256 399BF5A8D5A45222E8D361823160CAA871815122ED46DBA26540F8E48328305A.
  Imagem conferida: sem Windows.old, sem system.conf do AnyDesk, sem RustDesk.toml, com wallpaper.png e GPO do Aluno.
  7z t no install.wim: "Everything is Ok" (1.086.630 arquivos, 159 GB expandido).
- VM EEEP-Teste (disco C:\win11EEEP\vm\teste\teste-v3full.vdi): instalou com o instalador novo, sem loop, tela de bloqueio
  e logon com o papel de parede.
- DEFEITO 1 (corrigido no script, falta entrar na ISO): logon do Aluno -> "Falha na entrada do servico Cliente da
  Politica de Grupo. Acesso negado." Causa: o sysprep troca o SID das contas locais, mas o NTUSER.DAT do Aluno/CREDE
  continua com ACL do SID antigo da maquina de montagem. Correcao: scripts\guest\EEEP-CorrigirPerfis.ps1, chamado pelo
  SetupComplete.cmd. Testado na VM: Aluno entra normalmente.
- DEFEITO 2 (em investigacao): notebook Acer (SSD 500 GB, ~20 GB RAM) reinicia sem mensagem apos a instalacao, com o
  instalador novo E com o classico. Setup terminou sem erro (logs em build\logs-note). Boot pelo Strelec
  ("Search & Start Windows") mostra winload.efi 0xc0000017 (memoria insuficiente). Secure Boot desligado: continua.
  bootmgfw.efi da imagem identico ao oficial. Proximo passo: Linux live no notebook com SSH por chave
  (mapa de memoria do firmware, efibootmgr, BCD da particao EFI, montar o Windows somente leitura).
- 18/11 tarde (Linux live + SSH, so leitura): notebook = Acer Aspire A315-53, i3-7020U (7a geracao), BIOS V2.02 2019,
  4+16 GB. Mapa de memoria e BCD normais. ISO OFICIAL 26300.9457 instala e INICIA no notebook -> hardware/BIOS nao sao
  a causa; o defeito esta na nossa imagem. Diferencas (nossa x oficial): hive SYSTEM 17 MB x 11,5 MB; drivers de boot
  a mais: PxHlpa64 (filtro de CD/DVD de terceiro), fse, lxss, VmsProxy, VMSNPXY; WdBoot/WdFilter da pasta wd\.
  Proximo teste: v3min (D:\EEEP\Win11Pro_EEEP_v3min.iso, 8,1 GB) no notebook, para separar "processo VM/sysprep/captura"
  de "programas/upgrade".
- 18/11: v3min INICIA no notebook -> processo VM/sysprep/captura OK; culpado = programas ou upgrade 23H2->26H2.
  Usuario decidiu: v3 DO ZERO (26H2 limpo + programas), sem reaproveitar sistemas antigos. Roteiro: ROTEIRO-V3.md;
  novo script scripts\v3\v3-base-programas.ps1. Apagados com autorizacao: teste-v3full.vdi, captura2025.vdi,
  captura2025-v2.vdi, D:\EEEP\vm\teste-v3.vdi, D:\EEEP\Win11Pro_EEEP_v3.iso (C: 270 GB livres, D: 122 GB).
  Pendente: usuario baixar de novo as ISOs do Adobe CS5.5 (apagadas para liberar espaco).
- 18/11 tarde: VM nova EEEP-v3full (C:\win11EEEP\vm\v3full; 4 CPU, 8 GB, a pedido do usuario) instalada do
  26H2 oficial 26300.9457 em modo de auditoria. Contas: Aluno + Administrador (CREDE NAO existe mais, pedido do
  usuario). Referencia limpa: 96 drivers de boot, SYSTEM 10,8 MB (= oficial no notebook). Snapshot 00-limpo-auditoria.
  Agente: tarefas agendadas ficam "Queued" no modo de auditoria -> agente sobe pela chave Run. DVD porta 1 = kit.viso.
  Passo 2 em andamento: Install-LabSoftware.ps1 -SkipPostgreSQL -SkipNmap (job v3full-02-kit-user).
- 18/11 noite: passos 2-6 instalados na EEEP-v3full (kit, base, PG18, engenharia, ALM, Autodesk, simuladores, Nmap/Npcap)
  e Adobe CS5.5 Master Collection (exit 0; extraido com 7z na VM, ISOs tem cauda de 168 bytes; Acrobat X Pro da suite,
  sem Acrobat DC). PxHlpa64 veio Start=0 -> ajustado para 3. Drivers de boot seguem 96 em todas as etapas.
  Snapshot 06c-adobe. Instaladores Adobe apagados da VM e hardlinks build\adobe apagados (originais em Downloads).
  Agentes apos reboot: Win+R "cmd" e depois "c:\a". Kaspersky do host apagou um job da fila que descompactava .gz
  em memoria -> evitar esse padrao (usar 7z). Proximo: Docker+WSL e ISO de teste para o notebook.
- 18/11 noite: WSL 3.0.5 + Docker Desktop (drivers de boot 96 -> 100: lxss, fse, VmsProxy, VMSNPXY, todos do Windows).
  VBoxSVC 7.2.20 caiu (0xc0000005) num snapshot AO VIVO -> tirar snapshots so com a VM desligada (07b-docker-desligada).
  VM EEEP-2025 apagada (autorizado). Usuario decidiu ir direto para a ISO final (sem ISO de teste).
  Passo 8: Postman + extensoes do VS Code no perfil Default (Aluno sem perfil na imagem); GPO/papel aplicados.
  Energia (pedido do usuario): sem suspensao/hibernacao, tela 15 min (v3-preparar-sysprep.ps1 + EEEP-PrimeiroBoot.ps1).
  Senhas definidas pelo usuario. Sysprep OK; snapshot 08-pos-sysprep. Boot pelo DVD: Esc -> Boot Manager -> CD-ROM VB1
  (sem isso a VM sobe pelo disco e comeca o specialize). Captura scripts\capture\capfull.cmd: 41 min, install.wim 62,13 GB.
- ISO v3 FINAL: C:\win11EEEP\Win11Pro_EEEP_v3.iso, 62,95 GB,
  SHA256 8F5AA21BB3381E44633668FD3A2764839E85BCA58444CB87AD6B9CF16C583EEF. Falta testar: notebook, VM limpa, Positivo.
- 19/11: ISO v3 INSTALA E INICIA no notebook Acer (passou do winload; 1o boot rodou script, 2o boot chegou a tela de
  bloqueio com o papel da escola). Usuario optou por nao testar em VM limpa. Falta: logon Aluno/Administrador, Positivo.
  Notebook: aviso "modulo impedido na Autoridade de Seguranca Local" = nimdnsNSP.dll (NI mDNS do Multisim) bloqueado pela
  protecao da LSA (ligada por padrao no 26H2 limpo) -> scripts\guest\EEEP-RemoverNSP-NI.ps1 (testado no notebook: OK).
  CodeBlocks e SimulIDE nao abriam no Aluno: Program Files\WinGet\Packages so para admins -> icacls Usuarios RX.
  Demais programas OK no Aluno. Correcoes entrando no install.wim por scripts\capture\patch-nsp.cmd (WinPE) +
  SetupComplete.cmd novo -> ISO v3.1.
  PowerShell piscando no logon: Run LabSetupConfigurarUsuario sem o script (60-limpeza apagava C:\ProgramData\LabSetup
  inteiro; corrigido) -> Configure-LabUser.ps1 devolvido (patch-labuser.cmd). AnyDesk ssl_a000415 no notebook = identidade
  criada com o relogio 3h adiantado (Linux live); recriar service.conf/system.conf. Nada a mudar na imagem.
- ISO v3.1: C:\win11EEEP\Win11Pro_EEEP_v3.1.iso, 63,2 GB,
  SHA256 AACC4A64C0DC083F5B1F2716DB7EA4D74BC09235182946CE4FFC6924FF77619F (patches 1-3 conferidos nos logs).
  Copia pedida pelo usuario em H:\ISO (pendrive/disco Ventoy), SHA256 conferido.
- 19/11: v3.1 TESTADA pelo usuario: "comportamento exemplar, tudo dentro do previsto". VERSAO FINAL DA V3.
  Limpeza autorizada: build\iso e vm\captura\captura-v3full.vdi apagados (ISO v3 antiga ja nao existia). C: 336 GB livres.
  Mantida a VM EEEP-v3full (snapshots 07b-docker-desligada e 08-pos-sysprep) para uma futura v3.2.
  Usuario: hipervisor do host reativado (bcdedit auto) e ISO v3.1 ja enviada ao Google Drive.
- Rebuild da ISO so depois do diagnostico do notebook (as duas correcoes na mesma recaptura, a partir do snapshot
  pos-sysprep-v3 da EEEP-2025, injetando os scripts no WinPE antes de capturar).
