# Roteiro da v3 completa (26H2) do zero

Decisão do usuário (18/11/2026): a v3 é montada sobre uma **instalação limpa** do 26H2 oficial
(`Windows11_Client_x64_pt-br_26300_9457.iso`). Nada é reaproveitado de VMs anteriores, e não há
upgrade de versão.

Motivo: a v3 feita por upgrade da EEEP-2025 não iniciava no notebook Acer (winload 0xc0000017). A ISO oficial e
a v3min (limpa, feita pelo mesmo processo de VM, sysprep e captura) iniciam normalmente.

Ao terminar cada passo, conferir os **drivers de inicialização** (serviços com Start=0) e o tamanho do hive
SYSTEM. Referência do 26H2 oficial no notebook: 96 drivers e SYSTEM com 11,5 MB.

## 0. Pré-requisitos
- Espaço livre: cerca de 170 GB para o disco da VM, 70 GB para a captura e 67 GB para a ISO.
- ISOs do Adobe CS5.5 Master Collection (discos 1 a 3), que o usuário vai baixar de novo.
- Na VM, o usuário digita:
  - o número de série do Adobe;
  - a senha do postgres;
  - as senhas de Aluno, Administrador e CREDE.
- Nenhuma senha fica em arquivo, log ou mensagem.

## 1. VM nova
- **VM:** `EEEP-v3full` em `C:\win11EEEP\vm\v3full`.
  - 4 CPUs, 8 GB de RAM e 64 MB de vídeo (o usuário pediu requisitos menores).
  - UEFI, TPM 2.0, Secure Boot e rede NAT.
  - Disco dinâmico de 350 GB.
- **DVDs:** a ISO oficial na porta 1 e `build\v3full.viso` na porta 2.
- **Instalação automática:** `scripts\v3\autounattend-full.xml` entra em modo de auditoria e chama `v3full.cmd`,
  que roda `v3full-inicio.ps1`. Esse script:
  - cria Aluno e Administrador (sem a conta CREDE, a pedido do usuário em 18/11);
  - desliga os avisos do OOBE;
  - desliga o Windows Update automático durante a montagem;
  - instala o agente de build.
  - Ele **não** roda o sysprep.
- **Agente de comandos:** `scripts\guest\Agente.ps1`, ligado à fila do host (`Servidor-Comandos.ps1`, porta 8765).
  No modo de auditoria as tarefas agendadas ficam em "Queued" e não executam, por isso o agente sobe pela chave
  `HKLM\...\Run` (EEEPBuild-sys e EEEPBuild-user), com os dois rodando como Administrador. O `71-sysprep.ps1`
  remove essas entradas.

## 2. Kit (instaladores locais, `implantacao-lab-windows11\Pacotes`)
- **`jobs\30-instalar-kit.ps1`** instala:
  - JDK 21 e Maven;
  - Eclipse e NetBeans 25;
  - Android Studio, SDK e Flutter;
  - Packet Tracer 9.0.1, VDE-CE e os modelos.
  - Ajustar o caminho `D:\kit`.
- **`Install-LabSoftware.ps1`** instala:
  - VS Code, Git e 7-Zip;
  - XAMPP 8.2, VirtualBox e LibreOffice;
  - Arduino IDE e Postman.
- **`jobs\54-extras-2025.ps1`** (só a parte dos instaladores locais) instala MySQL Workbench 8.0.36,
  Portugol 2.7.5, Dev-C++ 4.9.9.2 e Proteus.
- **`jobs\56-visualg.ps1`** instala o VisuAlg 3.0.7.
- **`jobs\33-xampp-servicos2.ps1`** registra Apache e MariaDB como serviços automáticos.
- **`jobs\53-nmap.ps1`** instala o Nmap e o Npcap. O instalador é **interativo**: Avançar até o fim.

## 3. Programas da base (WinGet, oficiais)
- **`scripts\v3\v3-base-programas.ps1`** instala:
  - Chrome, Firefox, Wireshark, LibreCAD e AnyDesk;
  - Inkscape, GIMP 3 e FreeCAD;
  - Code::Blocks, Node.js LTS e IntelliJ;
  - Google Earth Pro e Python 3.14.
- **`jobs\52-python-anaconda.ps1`** instala o Anaconda para todos os usuários (só a parte da instalação).
- **`jobs\51-extras.ps1`** instala o Fusion para todos os usuários (só a parte do Fusion).

## 4. Banco de dados
- **`jobs\55-pg18.ps1`** instala o PostgreSQL 18 e o pgAdmin. O usuário digita a senha numa janela.

## 5. Engenharia e CAD
- **`jobs\59-solidedge-sinutrain.ps1`** e **`jobs\61-proteus-sinutrain.ps1`** instalam Solid Edge 2026,
  SinuTrain 4.95, Multisim 14.2 (ISO NI em `build`) e PSIM Demo.
  Na v3 do zero, isso foi feito pelo `scripts\v3\v3-engenharia.ps1`:
  - O pacote 4.5 HF1 foi trocado pelo **SinuTrain 4.95** (`sinutrain495.zip`). Ele instalou com `setup.exe /s`.
  - O **Automation License Manager** recusa o MSI direto (1603, "TestSuppositions failed"). Ele só instala pelo
    `setup\Setup.exe` geral da Siemens, com interface, **depois de reiniciar**. Nesse setup, só o ALM fica marcado
    e no fim escolhe-se "restart later". Os cliques foram feitos com `scripts\v3\Clicar.ps1`, porque o teclado
    virtual não alcança a janela.
  - O Multisim devolve -125071, mas instala; o Visual C++ devolve 1638, que significa versão mais nova presente.
  - O KeyShot Studio vem junto com o Solid Edge.
- **`jobs\43-acad-instalar.ps1`** instala o AutoCAD 2027 (`build\acad2027`).
- **`jobs\40-revit2027.ps1`** instala o Revit 2027 (`build\revit2027`), só a parte da instalação.

## 6. Itens com download manual (site oficial)
- **Open FluidSim** e **SimulIDE:** baixar o zip oficial, extrair em `C:\Program Files` e criar atalhos
  públicos.
- **Adobe CS5.5 Master Collection:** inclui o Acrobat X Pro e o LiveCycle ES2.
  - Uma unidade de DVD na VM, trocando o disco 1 → 2 → 3 com `--forceunmount`.
  - O usuário digita o número de série.
  - Depois, `jobs\41-remover-acrobat.ps1` remove o Acrobat DC/Reader, se ele aparecer.
  - Conferir o driver `PxHlpa64` (gravação de DVD, que vem com o Premiere/Encore). Se estiver com Start=0,
    passar para Start=3.

## 7. Docker e WSL (por último entre os programas)
- **`jobs\90-v2-programas-docker.ps1`**, só a parte do WSL e do Docker: recursos WSL/VirtualMachinePlatform,
  Microsoft.WSL, Docker Desktop (WSL2, serviço sempre ativo) e o grupo docker-users com Aluno e Administrador.
- **Conferir os drivers de boot** (`lxss`, `VmsProxy`, `VMSNPXY`). Antes de seguir, **fazer uma ISO de teste
  e ver se ela inicia no notebook** (suspeito do 0xc0000017).

## 8. Perfis, GPO e papel de parede
- **`jobs\50-perfis.ps1`:** Postman e extensões do VS Code nos perfis Administrador e Aluno, e atalhos.
- **`scripts\v3\Aplicar-GPO-Papel.ps1`:**
  - restrições do Aluno pela política de "Não administradores";
  - `C:\wallpaper.png` para todos;
  - papel na tela de bloqueio e de login.
- Testar o logon do Aluno: papel de parede, personalização bloqueada e programas abrindo.

## 9. Limpeza e sysprep
- **`jobs\60-limpeza.ps1`:** temporários, instaladores e caches.
- **`jobs\70-preparar-sysprep.ps1`:** PrimeiroBoot, unattend e pacotes da Store por usuário.
- **Windows Update:** remover a política
  `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\NoAutoUpdate`, posta pelo `v3full-inicio.ps1`.
- **Copiar `EEEP-PrimeiroBoot.ps1`:** colocar em `C:\Windows\Setup\Scripts` e registrar a tarefa
  EEEP-PrimeiroBoot, como no `v3min.ps1`.
- **WinRE:** `reagentc /disable`, para o Winre.wim ir junto na captura.
- **Copiar para `C:\Windows\Setup\Scripts`:** `SetupComplete.cmd` (versão nova) e
  `EEEP-CorrigirPerfis.ps1`, que corrige a ACL do NTUSER do Aluno depois do sysprep.
- **AnyDesk/RustDesk:** apagar IDs e senhas (`EEEP-PrimeiroBoot.ps1` também apaga no primeiro boot).
- **`jobs\71-sysprep.ps1`:** `sysprep /generalize /oobe /shutdown`.

## 10. Captura e ISO
- **`scripts\capture\cap26.cmd`** (WinPE) captura para o VDI novo.
- **`scripts\host\Montar-ISO.ps1`** monta a ISO a partir do instalador oficial 26300.9457.
- Calcular o SHA256 e anotar no ESTADO.md.

## 11. Testes
- **VM limpa:** instalação sem looping e sem OOBE, logon do Aluno sem erro de GPO, papel de parede e IDs novos
  do AnyDesk e do RustDesk.
- **Notebook Acer e Positivo:** o boot precisa passar do winload.
