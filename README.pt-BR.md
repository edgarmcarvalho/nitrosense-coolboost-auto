# nitrosense-coolboost-auto

**CoolBoost™ automático para notebooks Acer Nitro**: desliga o CoolBoost na bateria, religa quando você conecta o carregador, liga enquanto você joga e oferece um ícone na bandeja para alternar com um clique. Tudo isso sem precisar abrir o NitroSense.

🇺🇸 [Read in English](README.md)

![Menu do CoolBoost Auto na bandeja](docs/screenshot.png)

> Projeto sem vínculo com a Acer e não endossado por ela. *Acer, Nitro, NitroSense e CoolBoost são marcas registradas da Acer Inc.*

## Recursos

- **Regra da bateria:** o CoolBoost **desliga** quando você tira o carregador, para as ventoinhas não gastarem bateria.
- **Regra da tomada:** ao conectar de novo, você escolhe o que acontece:
  - **Restaurar estado anterior** (padrão)
  - **Sempre LIGAR**
  - **Sempre DESLIGAR**
  - **Deixar como está**
- **Modo jogo:** o CoolBoost **liga** enquanto um jogo está aberto e volta ao estado anterior quando o jogo fecha.
  - Os jogos são detectados pela lista de jogos do próprio Windows, pelas bibliotecas da Steam e pelos jogos da Rockstar, além de qualquer app que você marcar. Jogos novos são reconhecidos automaticamente.
  - Desinstaladores, relatórios de erro e launchers são ignorados.
  - Se você mudar o CoolBoost manualmente no meio do jogo, a automação respeita a sua escolha até o jogo fechar.
  - Na bateria, a regra da bateria tem prioridade.
- **Ícone na bandeja (estilo NitroSense):**
  - Ventoinha vermelha = LIGADO, cinza = DESLIGADO, selo verde = jogo aberto.
  - Clique esquerdo alterna. Clique direito mostra todas as opções.
  - Sem pedidos de administrador (UAC).
- **Sem janela do NitroSense.** O CoolBoost é alternado pela mesma chamada de firmware que o NitroSense usa, e a configuração do próprio NitroSense é mantida em sincronia, então o app sempre mostra o estado certo.

## Compatibilidade

| | |
|---|---|
| **Testado em** | Acer Nitro 5 **AN515-55**, Windows 11, NitroSense 3.01 |
| **Provavelmente funciona em** | Outros Acer Nitro / Predator cujo firmware tenha a interface WMI `APGeAction` |
| **Requer** | NitroSense instalado, Windows PowerShell 5.1 (já incluso no Windows 10/11), conta de administrador para instalar |

O instalador verifica o notebook antes de qualquer coisa. Se o modelo não suportar essa interface, ele para sem alterar nada. Se testar em outro modelo, abra uma issue contando se funcionou.

## Instalação

1. Baixe o **`CoolBoostAuto-Setup-x.y.z.exe`** da [versão mais recente](https://github.com/edgarmcarvalho/nitrosense-coolboost-auto/releases/latest).
2. Execute, aceite o pedido de administrador (UAC) e avance pelo assistente.
   - O assistente verifica o notebook primeiro. Se o modelo não for compatível, ele para antes de instalar qualquer coisa.
   - O SmartScreen do Windows pode avisar porque o instalador não tem assinatura digital: **Mais informações → Executar assim mesmo**.
3. Um ícone de ventoinha vermelha aparece ao lado do relógio. Ele pode estar escondido na setinha **^**; arraste-o para a barra de tarefas para deixá-lo sempre visível.

Rodar uma versão mais nova do instalador atualiza a instalação e mantém suas configurações.

<details><summary>Prefere scripts? Instalação sem o assistente</summary>

Baixe o `CoolBoostAuto-Scripts-x.y.z.zip` da versão (ou **Code → Download ZIP**), extraia e clique com o botão direito em **`install.ps1`** → **Executar com o PowerShell**. Opções: `-NoAutostart` (não iniciar o ícone ao fazer login). Para remover: **`uninstall.ps1`**, com `-KeepSettings` para guardar suas configurações.
</details>

## Desinstalação

**Configurações → Aplicativos → Aplicativos instalados → CoolBoost Auto → Desinstalar.** O CoolBoost fica no estado em que estiver.

## Como usar

Clique com o botão direito no ícone da bandeja:

- **Turn CoolBoost ON / OFF** (ligar / desligar)
- **Automation**
  - **Turn off on battery**: desligar na bateria
  - **When plugged in**: ao conectar o carregador; restaurar / sempre ligar / sempre desligar / deixar como está
  - **Turn ON while gaming**: ligar durante jogos
  - **Mark a running app as a game**: marcar um app aberto como jogo, para o que não for detectado sozinho
  - **Stop treating as a game**: deixar de tratar como jogo, se algo disparar por engano (*Reset exclusions* desfaz)
- **Open NitroSense** / **Open log**

Também dá para reabrir o ícone pelo menu Iniciar: **CoolBoost Tray**.

## Como funciona

| Parte | Onde | Roda como |
|---|---|---|
| Serviço (`CoolBoostSys.ps1`) | `C:\Program Files\CoolBoostAuto` (só administradores alteram) | SYSTEM, via tarefas agendadas |
| Ícone (`CoolBoostTray.ps1`) | `C:\ProgramData\CoolBoostAuto` | você |
| Configurações (`settings.json`), log do ícone | `C:\ProgramData\CoolBoostAuto` | — |
| Log do serviço | `C:\Program Files\CoolBoostAuto\CoolBoostAuto.log` | — |

**Tarefas agendadas**
- `CoolBoostAuto` roda ao conectar/desconectar o carregador (evento 105 do Kernel-Power), na inicialização e ao voltar da suspensão.
- `CoolBoostToggle`, `CoolBoostOn` e `CoolBoostOff` podem ser iniciadas por usuários comuns. É assim que o ícone alterna o CoolBoost sem precisar de administrador.

**A chamada do CoolBoost:** o estado é lido com `APGeAction.GetFunction(0x207)` (fica no byte 1) e definido com `APGeAction.SetFunction((estado << 16) | 7)`, no namespace `root\WMI`.

**Segurança**
- A parte que roda como SYSTEM fica numa pasta que só administradores podem alterar.
- Do arquivo de configurações, que o usuário pode editar, ela só lê valores verdadeiro/falso e uma lista fixa de opções.
- Sem acesso à internet e sem telemetria.

## Como o instalador é gerado

As versões são geradas pelo GitHub Actions ([`.github/workflows/release.yml`](.github/workflows/release.yml)) sempre que uma tag `v*` é enviada. Ele compila o [`installer/setup.iss`](installer/setup.iss) com o Inno Setup e anexa o instalador, um zip com os scripts e os checksums à versão. Para gerar localmente: `ISCC.exe /DAppVersion=0.9.0 installer\setup.iss`.

## Limitações conhecidas

- Testado apenas no AN515-55. Outros modelos podem usar chamadas de firmware diferentes.
- Se você fechar o ícone da bandeja com um jogo aberto, o CoolBoost fica no estado atual.
- O jogo é identificado pelo executável. Jogos que abrem por um launcher são detectados quando o processo real do jogo inicia.

## Créditos

- O comando de firmware do CoolBoost foi identificado graças ao **[OpenPredator](https://github.com/KRWCLASSIC/OpenPredator)**, de KRWCLASSIC (MIT), uma reimplementação open source do NitroSense/PredatorSense. Nenhum código foi copiado; a chamada foi verificada de forma independente num AN515-55.
- Criado por [@edgarmcarvalho](https://github.com/edgarmcarvalho) com ajuda do Claude (Anthropic).

## Licença

[MIT](LICENSE). Fornecido "como está", sem garantia. Use por sua conta e risco.
