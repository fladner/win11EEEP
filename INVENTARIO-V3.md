# Inventário de programas para a v3 (26H2 limpa)

Levantado em 17/11/2026 a partir dos atalhos do Menu Iniciar da imagem **v2** (`install.wim` validado).
Legenda da origem:
- **KIT**: instalador já está em `implantacao-lab-windows11\Pacotes` ou `build\`.
- **AUTO**: Claude baixa (winget ou site oficial, gratuito/livre).
- **CONTA**: precisa de login do usuário.
- **USUÁRIO**: comercial/antigo, só com instalador e licença do usuário.

## Desenvolvimento
| Programa | Origem |
|---|---|
| VS Code + extensões | KIT |
| Git | KIT |
| Python 3.14 | AUTO |
| Anaconda | AUTO |
| Node.js LTS | AUTO |
| JDK 21 Temurin, Maven 3.10.1 | KIT |
| Eclipse IDE for Java | KIT |
| NetBeans 25 | KIT |
| IntelliJ IDEA | AUTO |
| Android Studio + SDK, Flutter | KIT |
| Dev-C++ 4.9.9.2 | KIT |
| Code::Blocks | AUTO |
| Portugol Studio 2.7.5 | KIT |
| VisuAlg 3.0.7 | KIT |
| Postman | KIT |
| Docker Desktop + WSL2 | AUTO |

## Web e banco de dados
| Programa | Origem |
|---|---|
| XAMPP 8.2.12 | KIT |
| PostgreSQL 18 + pgAdmin (senha digitada pelo usuário) | KIT |
| MySQL Workbench 8.0 | KIT |

## Redes
| Programa | Origem |
|---|---|
| Cisco Packet Tracer 9.0.1 | KIT |
| Wireshark + Npcap | AUTO |
| Nmap | KIT |
| VirtualBox | KIT |

## CAD, engenharia e eletrônica
| Programa | Origem |
|---|---|
| AutoCAD 2027, Revit 2027 | KIT (`build\acad2027`, `build\revit2027`) |
| Autodesk Fusion | KIT (Fusion Client Downloader) |
| Solid Edge 2026 Student | KIT |
| SinuTrain 4.95 (+ Automation License Manager) | KIT |
| Multisim / Ultiboard 14.2 | KIT |
| Proteus 9 Demo | KIT |
| PSIM Demo | KIT |
| FreeCAD 1.1, LibreCAD | AUTO |
| Arduino IDE 2.3.11 | KIT |
| SimulIDE | AUTO |
| Open FluidSim | AUTO |
| **FluidSIM Pneumática 3.6 (estudantes, Festo)** | **USUÁRIO** |
| **KeyShot Studio** | **USUÁRIO** |

## Escritório, gráficos e navegação
| Programa | Origem |
|---|---|
| LibreOffice | KIT |
| GIMP 3.2, Inkscape | AUTO |
| Firefox, Google Chrome | AUTO |
| Google Earth Pro | AUTO |
| 7-Zip | KIT |
| **Adobe Master Collection CS5.5** (Photoshop, Illustrator, InDesign, Premiere, After Effects, Dreamweaver, Flash etc.) | **USUÁRIO** |
| **Adobe Acrobat X Pro + Distiller** | **USUÁRIO** |
| **Adobe LiveCycle Designer ES2** | **USUÁRIO** |

> 17/11: Adobe (CS5.5, Acrobat X Pro, LiveCycle ES2): o usuário cuida — tem os instaladores e as escolas mantêm as
> licenças. Claude não baixa nada da Adobe; o usuário fornece as ISOs da Adobe na configuração da v3 completa.
> ISOs baixadas de novo em 18/11 (as de 17/11 foram apagadas para liberar espaço):
> `%USERPROFILE%\Downloads\Adobe Creative Suite 5.5 Master Collection-disc1.iso` (7,07 GB), `-disc2.iso` (6,70 GB),
> `-disc3.iso` (3,89 GB). O 7-Zip lê as três inteiras. (Mídia original: Set-up.exe + leia-me; a Master Collection CS5.5 traz o
> Acrobat X Pro, e o LiveCycle Designer ES2 vem junto com ele). Na VM: UMA só unidade de DVD (mesma letra),
> trocando a mídia em sequência (disc1 -> disc2 -> disc3) quando o instalador pedir
> (`VBoxManage storageattach ... --medium <proximo.iso> --forceunmount`); o usuário digita o número de série.
> KeyShot Studio: vem agregado a outro programa da lista (não instalar separado). FluidSIM 3.6: substituído pelo
> Open FluidSim.

## Acesso remoto e escola
| Programa | Origem |
|---|---|
| AnyDesk, RustDesk 1.5.3 | AUTO / KIT |
| Agente VDE-CE 0.8.1 | KIT |

## Fora da lista (vieram da base antiga e não precisam voltar)
- Windows Performance Toolkit (ferramenta de diagnóstico do Windows SDK)
