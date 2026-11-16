CoolBoost Auto - README                                  (Portugues: abaixo)
==============================================================================

WHAT IT IS
Automatic CoolBoost for Acer Nitro laptops. It turns CoolBoost off on battery,
back on your terms when you plug in, and on while you are gaming. One click on
the fan icon next to the clock switches it whenever you want. NitroSense does
not have to be open. It never sets fan speeds or fan curves.

HOW TO INSTALL

  EASIEST (no zip needed)
  Open PowerShell (Start menu > type PowerShell > Enter), paste this line with
  a right-click and press Enter:

    irm https://raw.githubusercontent.com/edgarmcarvalho/nitrosense-coolboost-auto/main/get.ps1 | iex

  FROM THIS ZIP
  1. If you have not extracted it yet: right-click the zip > Properties >
     tick "Unblock" > OK. Then right-click the zip > Extract All.
  2. Open the extracted folder (the one that contains install.ps1).
  3. Click the address bar at the top of the folder window, type  powershell
     and press Enter. A blue PowerShell window opens in that folder.
  4. Type this and press Enter:

       powershell -ExecutionPolicy Bypass -File .\install.ps1

     (Double-clicking install.ps1 or "Run with PowerShell" does NOT work on a
     default Windows. This line does.)
  5. Windows asks for administrator permission: click Yes. The installer
     checks your laptop first and installs nothing if it is not supported.
  6. When it says "CoolBoost Auto is installed", look for the fan icon next
     to the clock (it may be under the ^ arrow). You can close the window.

  To update, run the same thing again. Your settings are kept.

HOW TO REMOVE
Settings > Apps > Installed apps > CoolBoost Auto > Uninstall.

IF SOMETHING GOES WRONG
- "Running scripts is disabled": use the exact line from step 4 above.
- Windows or your antivirus warns about the file: the PowerShell line at the
  top is not blocked. The scripts are plain text, so you can read them first.
- Anything else: tell us your laptop model and what the window showed.
  https://github.com/edgarmcarvalho/nitrosense-coolboost-auto/issues

More details (settings, games, FAQ):
https://github.com/edgarmcarvalho/nitrosense-coolboost-auto

Not affiliated with or endorsed by Acer. Acer, Nitro, NitroSense and CoolBoost
are trademarks of Acer Inc. MIT license (see LICENSE).


==============================================================================
CoolBoost Auto - LEIAME
==============================================================================

O QUE E
CoolBoost automatico para notebooks Acer Nitro. Desliga o CoolBoost na
bateria, liga de volta do seu jeito quando voce conecta o carregador e liga
durante os jogos. Um clique na ventoinha ao lado do relogio troca quando voce quiser. O
NitroSense nao precisa estar aberto. Nunca define velocidade nem curva dos
coolers.

COMO INSTALAR

  JEITO MAIS FACIL (sem precisar do zip)
  Abra o PowerShell (menu Iniciar > digite PowerShell > Enter), cole esta
  linha com o botao direito do mouse e aperte Enter:

    irm https://raw.githubusercontent.com/edgarmcarvalho/nitrosense-coolboost-auto/main/get.ps1 | iex

  POR ESTE ZIP
  1. Se ainda nao extraiu: clique com o botao direito no zip > Propriedades >
     marque "Desbloquear" > OK. Depois botao direito no zip > Extrair tudo.
  2. Abra a pasta extraida (a que contem o install.ps1).
  3. Clique na barra de enderecos no topo da janela da pasta, digite
     powershell e aperte Enter. Abre uma janela azul do PowerShell nessa pasta.
  4. Digite isto e aperte Enter:

       powershell -ExecutionPolicy Bypass -File .\install.ps1

     (Duplo clique no install.ps1 ou "Executar com o PowerShell" NAO funciona
     num Windows padrao. Esta linha funciona.)
  5. O Windows pede permissao de administrador: clique em Sim. O instalador
     verifica o notebook primeiro e nao instala nada se ele nao for
     compativel.
  6. Quando aparecer "CoolBoost Auto is installed", procure a ventoinha ao
     lado do relogio (pode estar na setinha ^). Pode fechar a janela.

  Para atualizar, faca o mesmo de novo. Suas configuracoes sao mantidas.

COMO REMOVER
Configuracoes > Aplicativos > Aplicativos instalados > CoolBoost Auto >
Desinstalar.

SE DER ERRADO
- "A execucao de scripts foi desabilitada": use exatamente a linha do passo 4.
- O Windows ou o antivirus avisa sobre o arquivo: a linha do PowerShell no
  topo nao e bloqueada. Os scripts sao texto puro, da para ler antes.
- Qualquer outra coisa: diga o modelo do notebook e o que a janela mostrou.
  https://github.com/edgarmcarvalho/nitrosense-coolboost-auto/issues

Mais detalhes (configuracoes, jogos, perguntas frequentes):
https://github.com/edgarmcarvalho/nitrosense-coolboost-auto/blob/main/README.pt-BR.md
