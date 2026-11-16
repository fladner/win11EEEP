# Programas da imagem EEEP 26H2 (v3) — roteiro para a ISO nova

Levantado dos testes feitos na VM em 15/11/2026, antes do sysprep. Os scripts em `scripts\jobs` instalam ou ajustam cada item.

## Desenvolvimento
- VS Code (16 extensões no perfil do Aluno)
- Python 3.14, Anaconda (`jobs\52`)
- Git
- JDK 21 (Eclipse Adoptium), Maven 3.10.1 (C:\Dev) (`jobs\30`)
- Eclipse (C:\Program Files\LabApps\Eclipse), NetBeans 25 (`jobs\30`)
- Android Studio, Android SDK (C:\Android), Flutter/Dart (C:\Dev\flutter) (`jobs\30`)
- Dev-C++, CodeBlocks
- Portugol Studio, VisuAlg 3.0.7
- Postman (perfil do Aluno)

## Web e banco de dados
- XAMPP 8.2.12, com Apache e MariaDB como serviços automáticos (`jobs\31`, `jobs\32`)
- PostgreSQL 18 + pgAdmin 4 (a senha do postgres fica com o usuário, fora do repositório)
- MySQL Workbench

## Redes
- Cisco Packet Tracer 9.0.1 (`jobs\30`)
- Wireshark + Npcap, Nmap (`jobs\53`)
- VirtualBox

## CAD, engenharia e eletrônica
- AutoCAD 2027 (`jobs\42`, `jobs\43`), Revit 2027 (`jobs\40`), Fusion 360 (`jobs\51`)
- Solid Edge 2026, SinuTrain
- FreeCAD 1.1, LibreCAD
- Arduino IDE, SimulIDE
- Proteus 9 Demonstration, Multisim 14.3, PSIM 11.1.3 Demo
- FluidSIM: não estava instalado (ausente no teste)

## Escritório e gráficos
- LibreOffice
- GIMP 3, Inkscape
- Atalho do Figma, modelos (`jobs\30`)

## Acesso remoto e escola
- AnyDesk, RustDesk: serviços automáticos, com ID novo em cada PC (`scripts\guest\EEEP-PrimeiroBoot.ps1`)
- Agente VDE-CE (não executar na VM)

## Removidos de propósito
- PostgreSQL 17, SketchUp 8, DAEMON Tools Lite, Adobe Acrobat 64-bit, Revit 2026
- Duplicados: NetBeans 16, Arduino IDE 2.0.3, LibreCAD 32-bit, GIMP 2.10 (`jobs\24`)

## Configuração (não são programas)
- Contas:
  - Administrador: ativo.
  - Aluno: com as GPOs de aparência e papel de parede.
  - CREDE: desativado.
- PATH da máquina: maven, java, nmap, flutter, mysql, adb, python, git, php, psql, code.
- Escrita do Aluno em C:\xampp\htdocs, C:\Dev\flutter e C:\Android.
- Sem avisos de OOBE, conta Microsoft e OneDrive (`scripts\guest\Desativar-AvisosOOBE.ps1`).
- Unattend: `scripts\guest\unattend-sysprep.xml` (SkipMachineOOBE/SkipUserOOBE) e `SetupComplete.cmd`.
