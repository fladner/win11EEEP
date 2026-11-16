# Instalação local do laboratório — Windows 11

Este kit foi preparado para ser executado individualmente em cada computador, sem depender de IP, domínio, WinRM ou descoberta de rede. Os aplicativos e SDKs ficam disponíveis para **todos os usuários locais**, inclusive contas padrão.

**Revisão 4 (13/11/2026) — menos erros de instalação:**

- O WinGet só é reparado quando não funciona ou está abaixo da versão 1.9. Antes, cada máquina consultava a API do GitHub de 4 a 5 vezes; com as 22 máquinas no mesmo link o limite de 60 consultas por hora estourava e o kit parava logo no início.
- Os códigos de retorno do WinGet são interpretados: "já instalado", "nenhuma atualização" e "reinicialização necessária" deixam de aparecer como `FALHA`. Erros definitivos não são repetidos; falhas de rede e "outra instalação em andamento" são repetidas com espera. O relatório mostra o motivo em português e o caminho do log de cada pacote.
- Antes de cada instalação o kit espera o Windows Update/outro MSI terminar (erro 1618) e cada instalador tem tempo limite; nada fica travado indefinidamente.
- Visual C++ 2015+ (x64 e x86) é instalado primeiro, porque VirtualBox, LibreOffice, XAMPP e PostgreSQL dependem dele.
- PostgreSQL: o `--override` apagava o modo silencioso do manifesto e o arquivo de opções era gravado com BOM, então o instalador abria a interface gráfica. Corrigido; uma pasta `data` deixada por tentativa anterior é renomeada.
- NetBeans usa o JDK 21 já instalado, sem baixar outro JDK como dependência.
- Nmap: a edição gratuita não aceita instalação silenciosa (só o Nmap OEM). O pacote do WinGet ainda estava no Nmap 7.80 de 2019. Agora o kit baixa o instalador atual de nmap.org (ou usa `nmap-*-setup.exe` de `Pacotes`) e o abre **no final**, com janela, para o técnico clicar em Avançar.
- Arduino IDE vem do MSI oficial pelo WinGet, sem consultar a API do GitHub. Maven e Android Command-line Tools vêm dos índices oficiais, com hash conferido, em vez de procurar texto em páginas HTML.
- Downloads vão para um arquivo `.part` e só entram no cache quando completos e conferidos; antes, um download interrompido falhava em todas as execuções seguintes.
- Flutter é extraído com 7-Zip/tar.exe (muito mais rápido) e liberado no Git (`safe.directory`) para contas padrão, que antes recebiam "dubious ownership".
- Packet Tracer é copiado para o disco local antes de instalar e o instalador é acompanhado só até o próprio processo terminar.
- No primeiro logon, a configuração do usuário espera a rede e o WinGet ficarem disponíveis e não roda duas vezes ao mesmo tempo.

**Revisão de 18/08/2026:** antes de instalar qualquer programa, o kit agora atualiza/repara o App Installer e o WinGet para todos os usuários, testa `winget --version` e atualiza o catálogo da fonte `winget`. Uma versão já superior à estável pública nunca é rebaixada.

**Correção da revisão 3:** a detecção de aplicativos agora lê diretamente as visões de 32 e 64 bits do Registro e ignora apenas entradas inválidas. Isso impede o erro `Conversão especificada não é válida` de bloquear NetBeans, Arduino IDE ou a detecção do Packet Tracer. A verificação do LibreOffice também aceita o executável compartilhado como evidência.

## Pacotes locais: baixar uma vez, instalar sem Internet

Para não baixar vários gigabytes em cada uma das 22 máquinas:

1. Num Windows 10/11 com WinGet e boa conexão (pode ser em casa), dê duplo clique em `BAIXAR-PACOTES.cmd`. Não precisa de administrador.
2. Ele guarda em `Pacotes` os instaladores de todos os programas do WinGet (`Pacotes\WinGet\<Id>`), além de Maven, Flutter, Nmap, Android Command-line Tools e VisuAlg. Rodar de novo só baixa o que falta; `-Force` renova as versões.
3. O Android SDK completo (`Pacotes\Android\android-sdk-api36.zip`) precisa de um JDK no computador. Se ele faltar, o item aparece como `MANUAL`: rode o kit na primeira máquina do laboratório e depois rode `BAIXAR-PACOTES.cmd` nela de novo, que ele compacta a pasta `C:\Android` já pronta.
4. O Cisco Packet Tracer exige login na NetAcad e continua sendo colocado à mão em `Pacotes`.

O instalador usa o que estiver em `Pacotes` e só vai à Internet para o que faltar. Se um pacote local falhar, ele tenta pelo WinGet automaticamente. Continuam usando a rede apenas a atualização do catálogo do WinGet e, no primeiro logon de cada usuário, as extensões do VS Code.

## Antes de ir às 22 máquinas

1. Extraia este kit em um pendrive ou pasta local.
2. Copie seu instalador oficial do Cisco Packet Tracer para a pasta `Pacotes`.
3. Baixe `visualg3.0.7.rar` da página oficial do projeto no SourceForge e coloque-o na mesma pasta `Pacotes`.
4. Opcionalmente, coloque o MSI oficial `arduino-ide_*_Windows_64bit.msi` em `Pacotes`; sem ele, o kit baixa a versão estável automaticamente.
5. Faça primeiro um teste completo em uma única máquina.
6. Confirme que há Internet, Windows 11 x64, privilégios administrativos e pelo menos 35 GB livres. O próprio kit atualizará o WinGet.

## Como executar em cada computador

1. Copie ou abra a pasta do kit.
2. Dê duplo clique em `INSTALAR-NESTE-PC.cmd`.
3. Aceite a elevação do Windows.
4. Leia o aviso e digite `INSTALAR`.
5. Informe a senha inicial da conta `postgres`. Ela fica somente em memória durante a instalação.
6. Aguarde a primeira etapa validar o WinGet; depois os programas serão instalados.
   No final, o instalador do Nmap/Npcap abre com janela: aceite a licença e clique em Avançar até concluir.
7. Reinicie o computador.
8. No primeiro acesso de cada usuário, aguarde a configuração automática e silenciosa do Postman, das extensões do VS Code e dos modelos pessoais.
9. `CONFIGURAR-USUARIO.cmd` fica disponível apenas para forçar uma nova tentativa manual no perfil atual.
10. Se quiser conferir depois, execute `VERIFICAR-NESTE-PC.cmd`.

O instalador grava log e relatório CSV em `C:\ProgramData\LabSetup\Logs`. A etapa de cada usuário grava seu log em `%LOCALAPPDATA%\LabSetup\Logs`.

## O que será instalado/configurado

| Item solicitado | Tratamento no kit |
| --- | --- |
| LibreOffice | Aplicativo por máquina via WinGet |
| VisuAlg (Portugol) | Extraído do RAR local; cria atalho público |
| MySQL (XAMPP) | XAMPP 8.2 por máquina; pasta compartilhada; usa MariaDB compatível no pacote atual |
| PostgreSQL | PostgreSQL 18 por máquina; serviço compartilhado e senha informada no momento |
| Figma (web) | Atalho público para o Figma Web |
| Visual Studio Code | Instalação por máquina; extensões configuradas em cada perfil |
| Spring Framework | Java, Maven, extensão Spring Boot por perfil, atalho e modelo pessoal |
| Postman | Instalado automaticamente em cada perfil; instalador validado é armazenado localmente |
| NetBeans | Aplicativo por máquina via WinGet |
| Java JDK/SDK | Eclipse Temurin JDK 21 LTS, `JAVA_HOME` e PATH da máquina |
| Eclipse | Eclipse IDE for Java Developers por máquina |
| Cisco Packet Tracer | Seu EXE local, com instalação silenciosa |
| Nmap | Instalador atual de nmap.org aberto no final, com cliques (a versão gratuita não instala em silêncio); PATH compartilhado |
| Kali Linux | Ignorado conforme solicitado |
| VirtualBox | Oracle VirtualBox base; nenhuma VM/ISO é criada |
| Arduino IDE | MSI oficial estável instalado por máquina (`ALLUSERS=1`) |
| Flutter | SDK estável oficial compartilhado em `C:\Dev\flutter` |
| Dart | Já incluído no Flutter SDK |
| Android Studio/SDK | Android Studio por máquina e SDK compartilhado com API 36 |
| Selenium | Dependência por projeto; cada usuário recebe seu próprio modelo Maven |

## Observações importantes

- O XAMPP atual distribui MariaDB em vez do Oracle MySQL. Para aulas SQL básicas é geralmente compatível; se a disciplina exigir especificamente MySQL Community Server, ele deve ser acrescentado separadamente.
- O kit não instala VirtualBox Extension Pack, Kali Linux, imagens de máquina virtual nem uma imagem de Android Emulator.
- O Android Emulator exige virtualização habilitada no BIOS/UEFI. VirtualBox e recursos de hipervisor do Windows podem afetar desempenho, mas o script não desativa nenhuma proteção do Windows.
- Packet Tracer, VisuAlg, Postman e extensões do VS Code são verificados no relatório; qualquer arquivo manual ausente aparece como `PENDENTE`, e você pode executar o kit novamente sem desinstalar o que já funcionou.
- O kit usa o procedimento oficial da Microsoft com o módulo `Microsoft.WinGet.Client` e `Repair-WinGetPackageManager -AllUsers`. Se a versão instalada estiver abaixo da estável pública, usa `-Force -Latest`; uma versão superior não sofre downgrade. Se a atualização ou o teste falhar, os demais pacotes não são iniciados com um catálogo antigo ou quebrado.
- Depois da atualização do WinGet, o catálogo comunitário `winget` é atualizado. Se necessário, somente essa fonte é redefinida e atualizada novamente.
- O instalador gratuito do Postman para Windows é por usuário. O kit armazena uma cópia oficial validada e registra uma configuração automática para cada perfil; não é necessário comprar o MSI Enterprise.
- Os demais aplicativos são instalados exclusivamente no escopo da máquina. Se um pacote não aceitar esse escopo, ele aparece como `FALHA` em vez de ser instalado somente para o administrador.
- Para permitir uso por contas padrão, o kit concede ao grupo local **Usuários** permissão de modificação nas pastas compartilhadas do Flutter, Android SDK, VisuAlg e XAMPP. Alunos poderão alterar essas ferramentas; restaure o laboratório periodicamente se as máquinas forem de uso não supervisionado.
- Configurações pessoais, projetos, extensões, coleções do Postman, bibliotecas do Arduino e máquinas virtuais continuam separados por usuário.
- A primeira execução de Maven, Selenium, Flutter ou Android pode baixar dependências adicionais.

## Velocidade nas 22 máquinas

Você pode iniciar o kit em todas elas, mas cada computador baixará vários gigabytes. Se o link de Internet ficar lento, inicie em grupos de 4 a 6. Packet Tracer, VisuAlg e o MSI opcional do Arduino são lidos diretamente de `Pacotes`.

## Diagnóstico rápido

- Cada pacote do WinGet tem log próprio em `C:\ProgramData\LabSetup\Logs\*.winget.log`; o caminho aparece na coluna Details do relatório.
- `Reinicialização pendente` ou `o Windows precisa ser reiniciado ANTES desta instalação`: reinicie e execute o kit de novo; o que já foi instalado é pulado.
- `outra instalação MSI (Windows Update) está em andamento`: aguarde o Windows Update terminar e execute novamente.
- `Nmap + Npcap PENDENTE`: execute o `nmap-*-setup.exe` indicado no relatório e clique em Avançar até o fim.

- `WinGet/App Installer FALHA`: reinicie o Windows e execute o kit novamente. Se persistir, confirme que a máquina alcança a PowerShell Gallery, o GitHub da Microsoft e os serviços de atualização do Windows.
- `fonte winget não pôde ser atualizada`: verifique proxy, firewall, data/hora e acesso a `cdn.winget.microsoft.com`.
- `Packet Tracer PENDENTE`: confirme que o EXE está dentro de `Pacotes` e contém “Packet” e “Tracer” no nome.
- `VisuAlg PENDENTE`: confirme que `visualg3.0.7.rar` está em `Pacotes`.
- `Postman PENDENTE` no perfil: entre novamente ou execute `CONFIGURAR-USUARIO.cmd`; confira `%LOCALAPPDATA%\LabSetup\Logs`.
- `Arduino IDE FALHA`: coloque o MSI oficial de Windows 64 bits em `Pacotes` e execute novamente.
- `Android SDK FALHA`: verifique acesso a `developer.android.com` e `dl.google.com`, depois execute novamente.
- `VirtualBox FALHA`: reinicie o Windows, aplique as atualizações pendentes e rode novamente.
- `PostgreSQL FALHA`: use uma senha que cumpra a política local do Windows e confira o log.
