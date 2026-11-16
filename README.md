# win11EEEP — ISO Windows 11 Pro 26H2 para os laboratórios EEEP

Scripts usados para gerar a ISO `Win11Pro_26H2_EEEP.iso`: Windows 11 Pro 26H2 (build 26300) com os programas
dos cursos técnicos, usuários `Administrador`, `Aluno` e `CREDE` preservados e políticas locais que impedem o
aluno de alterar a aparência do sistema. A ISO usa o instalador oficial do Windows 11 26H2 e instala em
qualquer computador compatível com os requisitos do Windows 11 (UEFI ou BIOS).

As imagens (`*.iso`, `*.wim`, discos de VM) e os instaladores do kit não ficam no repositório.

## Como a ISO foi construída

1. A ISO EEEP anterior (25H2) foi instalada numa VM VirtualBox (`scripts/host`, `scripts/vmkeys.ps1`).
2. Dentro da VM, por um agente temporário (`scripts/guest/Agente.ps1` + `scripts/host/Run-Guest.ps1`), foram
   executadas as etapas em `scripts/jobs`, em ordem numérica: Windows Update até o 26H2, atualização dos
   programas pelo winget, instalação direta dos programas do kit `implantacao-lab-windows11` em escopo de
   máquina, XAMPP com Apache e MariaDB como serviços automáticos, PostgreSQL 18, Revit 2027, AutoCAD 2027,
   Fusion 360, remoção de programas antigos/duplicados, Postman e extensões do VS Code no perfil do Aluno.
3. `scripts/guest/Desativar-AvisosOOBE.ps1` desativa, para todos os perfis, as telas de "terminar de configurar",
   conta Microsoft, backup e OneDrive.
4. Limpeza (`jobs/60-limpeza.ps1`), preparação (`jobs/70-preparar-sysprep.ps1`) e generalização
   (`jobs/71-sysprep.ps1`, arquivo de resposta `scripts/guest/unattend-sysprep.xml`).
5. No primeiro boot de cada computador, `scripts/guest/EEEP-PrimeiroBoot.ps1` gera identidade própria
   (MachineGuid, IDs do AnyDesk e do RustDesk, preservando senha e servidor do RustDesk) e reativa o Administrador.
6. Captura pelo WinPE da ISO oficial (`scripts/capture/cap.cmd`) e montagem da ISO (`scripts/host/Montar-ISO.ps1`):
   instalador oficial 26H2 + `install.wim` capturado + `ei.cfg` (Pro), gerada com `oscdimg` (UDF, boot BIOS+UEFI).

## Gravação em pendrive

O `install.wim` passa de 4 GB: grave o pendrive em **NTFS** (Rufus ou Ventoy). Em DVD virtual/VM funciona direto.

## Observações

- AutoCAD, Revit e Fusion 360 pedem login de conta Autodesk (educacional); o Packet Tracer pede conta NetAcad.
- O emulador do Android exige virtualização habilitada na BIOS/UEFI de cada PC.
- Senhas não ficam neste repositório.
