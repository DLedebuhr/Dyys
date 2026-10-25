# OPHELIA — nova cena da personagem

Este pacote cria uma personagem independente em `res://ophelia/OPHELIA.tscn`. Os scripts novos ficam dentro de `ophelia/` e não substituem `Player.gd`, `Player.tscn`, `PontoOrigem.gd` ou os outros scripts antigos. As artes continuam apontando para os arquivos que já existem em `res://assets/textures/Characters/Ophelia/`.

## 1. Instalação

1. Extraia a pasta `ophelia` na raiz do projeto, ao lado de `project.godot`, `assets` e `scenes`. O resultado precisa ser `res://ophelia/OPHELIA.tscn`, e não uma pasta ophelia dentro de outra.
2. Feche o editor antes de atualizar o arquivo de configuração para ele não sobrescrever as alterações na saída.
3. Abra um terminal na raiz do projeto e execute:

```powershell
python ophelia/configuracao/aplicar_inputmap.py project.godot
```

O programa faz uma cópia `project.godot.antes_ophelia_DATA.bak`, atualiza as ações desta personagem e conserva as outras configurações e ações do projeto. Não muda a cena principal nem os autoloads. Os nomes das camadas são acrescentados apenas quando o projeto ainda não possui a seção correspondente.

Se preferir configurar manualmente, use a tabela abaixo no InputMap do editor. O arquivo `configuracao/InputMap_Ophelia.cfg` contém a seção completa para consulta. Nenhum script da personagem cria ou remapeia ações durante o jogo.

4. Reabra o projeto e aguarde a importação dos scripts. Abra **`ophelia/testes/CenarioTeste.tscn` e execute essa cena com F6**. Ela contém chão, plataformas, alvo, indicadores de vida e comandos para testar a defesa.
5. Depois de conferir as mecânicas, instancie `ophelia/OPHELIA.tscn` no seu cenário de jogo. Mantenha o Player antigo salvo como referência. `OPHELIA.tscn` é a cena da personagem, portanto executá-la isoladamente, sem cenário/chão, faz a personagem cair.

## 2. Artes e ajustes que precisam ser conferidos

Os sprites, animações, gradientes e marcadores encontrados na cena enviada foram reaproveitados. As imagens não foram anexadas à conversa, então o ZIP não contém cópias delas nem imagens substitutas. Ele usa os mesmos caminhos do seu projeto.

Para conferir os caminhos antes de abrir a cena:

```powershell
python ophelia/configuracao/verificar_assets.py .
```

Os valores conhecidos da cena foram transportados: andar 200, correr 400, pulo -690, gravidade da planagem 0,5, queda planando 100, alcance de ataque 200, alcance de gancho 700, escala do sprite e posições dos marcadores das asas.

**Ajustes feitos no seu editor depois do último envio não estão nos anexos.** Confira especialmente:

| Onde | O que configurar |
|---|---|
| `OPHELIA`, grupo Reações → Transição para a frente | Quadros Transição Base e Quadros Transição Chapéu, caso você tenha as imagens intermediárias. |
| `OPHELIA/Lenco`, grupo Ataque à distância | Textura Projétil e Tamanho Projétil. A textura personalizada não aparece na cena anexada. |
| `OPHELIA/Lenco`, grupo Lenço de frente | Ajustes finos da gola e das origens por quadro, se você os modificou depois do envio. |
| `OPHELIA/Lenco/Efeitos` | Cor, intensidade, duração e quantidade dos efeitos. Esta é a única instância usada. |
| `OPHELIA/Vitalidade` | Vida máxima e intervalo de invulnerabilidade após dano. Valores iniciais: 100 e 0,5 s. |

A cena recebida não tinha TransicaoBase/Chapeu. O script aceita seus quadros pelo Inspetor e usa uma passagem simples entre perfil/frente quando eles estão vazios. Essa alternativa é funcional, mas não inventa desenhos intermediários. Se adicionar animações TransicaoBase/Chapeu diretamente aos SpriteFrames, elas também são reconhecidas.

## 3. Controles definitivos no InputMap

| Ação | Controle | Comportamento |
|---|---|---|
| `ControleAndarEsquerda` | A / seta esquerda | Movimento para a esquerda. |
| `ControleAndarDireita` | D / seta direita | Movimento para a direita. |
| `ControleCorrer` | CapsLock | Alterna andar/correr. |
| `ControlePular` | W | Pula; outro aperto no ar inicia a planagem, com a habilidade liberada. |
| `ControleSentarLevantar` | S | Senta/levanta no chão. |
| `ControlePropulsor` | S | Golpe do lenço e impulso no ar; não conflita com sentar no chão. |
| `ControleAtaqueLenco` | Q | Ataque normal ou disparo, conforme o modo. |
| `ControleDefesaLenco` | E | Defesa circular temporária. |
| `ControleTrocarAtaque` | Shift | Alterna ataque normal/à distância. |
| `ControleFixarLenco` | Mouse esquerdo | Prende o gancho; soltar o botão desfaz a ligação. |
| `ControleImpulsoLenco` | Mouse direito | Impulso ao apoio ou lançamento de objeto leve. |
| `ControleMostrarAlcance` | Tab | Mostra o alcance do gancho. |

O prefixo `Controle` distingue uma entrada de uma animação ou identificador de habilidade. As funções do ataque não incluem mais a letra Q em seu nome.

### Ferramentas de desenvolvimento

| Ação/controle | Uso |
|---|---|
| Sequência 666 | Alterna o modo debug; dígitos também estão definidos no InputMap. |
| V | Voo livre de teste. |
| Setas para cima/baixo | Eixo vertical durante o voo de teste. |
| H | Alterna o chapéu. |
| Z / X | Irritada / Agradecer. |
| T | Teletransporta os pés para o mouse. |
| K / J | Aprende próxima habilidade / esquece habilidades aprendidas. |
| L | Câmera lenta para calibrar animações. |
| B, somente no cenário de teste | Lança um projétil hostil contra a personagem. |
| N, somente no cenário de teste | Restaura vida e o alvo de treino. |

O cenário de teste liga o debug para permitir testar todas as ações; isso não altera a lista de habilidades aprendidas de verdade. Na cena OPHELIA usada no jogo, as habilidades aprendidas começam bloqueadas até seu desbloqueio, como antes.

## 4. O que foi preservado

- Movimento com aceleração/frenagem, pulo variável, tolerância na borda e pulo antecipado.
- Sentar/levantar e verificação de teto.
- Planagem com asas, revelação, recolhimento e brilho.
- Reações, transições espelhadas, versões Base/Chapeu e EsperarMovimento.
- Lenço acompanhando a gola, movimento e pose frontal.
- Círculo da defesa com saída reta, sentidos opostos das fitas e encontro na altura da gola.
- Ataque normal de 10 de dano; dois projéteis de 5 de dano cada.
- Projéteis visíveis, independentes das pontas do lenço, parados por cinco segundos antes do retorno.
- Coleta antecipada por contato e apoio temporário para o gancho.
- Gancho, balanço, apoio móvel e impulso de objetos leves.
- Propulsor: lenço golpeia na direção do mouse e personagem recebe impulso contrário no auge; brilho nas pontas.
- Sombra, troca de chapéu, voo debug, teletransporte e ferramentas de calibração.

## 5. O que mudou na organização e na execução

### Cena e nomes

| Nó | Responsabilidade |
|---|---|
| `OPHELIA` | Corpo físico e coordenação geral. |
| `ColisaoCorpo` | Colisão diretamente vinculada ao CharacterBody2D. |
| `Entrada` | Captura aperto/soltura pelo InputMap. |
| `Habilidades` | Permissões e desbloqueios reais. |
| `Vitalidade` | Vida, intervalo de dano e eventos de combate. |
| `Visual/Sombra` | Sombra no chão. |
| `Visual/EfeitosTras` | Camada traseira dos efeitos. |
| `Visual/FitaTras` e `Visual/FitaFrente` | As duas linhas do lenço. |
| `Visual/SpritePersonagem` | Sprite principal. |
| `Visual/Asas` | Visual da planagem e marcadores. |
| `Sensores/SensorTeto` | Verifica teto ao levantar. |
| `Sensores/SensorGancho` | Seleciona âncoras. |
| `Sensores/SensorInteracao` | Detecta áreas de interação. |
| `Lenco/OrigemLenco` | Origem espacial explícita. |
| `Lenco/AreaAtaque` | Área de dano já configurada na cena. |
| `Lenco/AreaDefesa` | Área circular do escudo já configurada na cena. |
| `Lenco/Efeitos` | Instância única dos efeitos do lenço. |
| `Ferramentas/VooDebug` e `Ferramentas/AtalhosDebug` | Recursos de desenvolvimento. |

As referências internas usam nomes únicos de cena ou o proprietário da cena. As buscas recursivas por qualquer nó parecido foram retiradas. O nó genérico com um projétil fixo não faz parte da nova personagem. Cada disparo instancia a sua própria cena `ProjetilLenco.tscn`.

### Componentes de código

| Arquivo | O que você altera nele |
|---|---|
| `Ophelia.gd` | Ordem de atualização, fila de comandos e interface pública da personagem. |
| `componentes/MovimentoOphelia.gd` | Regras de locomoção, pulo e planagem. |
| `componentes/ReacoesOphelia.gd` | Fluxo de reações e transições. |
| `componentes/AnimacaoOphelia.gd` | Nomes, espelhamento, troca de chapéu e reprodução do sprite. |
| `componentes/InteracoesOphelia.gd` | Áreas de interação, consulta do catálogo e efeito da batida do pé. |
| `componentes/HabilidadesOphelia.gd` | Desbloqueios e modo debug. |
| `lenco/ControladorLenco.gd` | Coordenação das ações e parâmetros do lenço. |
| `lenco/VisualLenco.gd` | Curvas, repouso, círculo, pontas e indicadores. |
| `lenco/CombateLenco.gd` | Ataque, defesa, disparos e propulsor. |
| `lenco/GanchoLenco.gd` | Âncoras, corda, balanço e objetos leves. |
| `efeitos/EfeitosComuns.gd` | Material, texturas radiais e configuração compartilhada das partículas. |
| `efeitos/EfeitosLenco.gd` | Composição visual dos efeitos do lenço. |
| `efeitos/RevelacaoAsas.gdshader` | Shader das asas, separado do texto GDScript. |
| `combate/DanoOphelia.gd` | Resolução padronizada do alvo e aplicação de dano. |
| `combate/VitalidadeOphelia.gd` | Vida, bloqueio e invulnerabilidade após dano. |
| `combate/EscudoOphelia.gd` | Interceptação de projéteis hostis pelo círculo. |

Os módulos de movimento/reação/animação e do lenço são objetos de código (`RefCounted`), não uma árvore extra de nós visuais. Recebem seu coordenador explicitamente. O estado e os parâmetros compartilhados continuam nos dois coordenadores, evitando cópias divergentes; o algoritmo especializado fica em cada módulo.

### Movimento físico

O fluxo normal calcula movimento e restrição da corda antes de chamar `move_and_slide()` uma única vez. O lenço não faz um segundo deslocamento concorrente do corpo durante o balanço. O voo livre debug possui seu modo de deslocamento separado, usado enquanto o coordenador normal está pausado.

### Aperto durante transição

Entradas discretas são registradas no aperto. A fila permite executar ataque, defesa, sentar ou pulo depois da transição sem exigir que a tecla permaneça pressionada. Uma ação do lenço que espera recarga não bloqueia um pulo. A direção de movimento continua sendo contínua: ao soltar A/D, a personagem freia.

O gancho mantém a semântica de segurar/soltar o mouse esquerdo. Aperto e soltura também são registrados em ordem; se ambos acontecerem durante uma transição, a ligação é criada e desfeita ao processar esses eventos. A fila é limitada a 12 comandos, ajustável no Inspector, para não crescer indefinidamente.

## 6. Defesa e integração com inimigos

A defesa agora funciona de duas formas complementares:

1. Durante a janela ativa, `OPHELIA.receber_dano(...)` bloqueia o dano sem reduzir a vida.
2. `AreaDefesa` intercepta projéteis do grupo `projeteis_hostis` ou com o método `bloquear_pelo_escudo()`.

A ativação começa em 60% da formação do círculo, conservando a temporização prevista no código anterior. Ela termina ao esgotar formação + tempo ativo. Esses tempos permanecem no Inspector do Lenco.

Para um inimigo causar dano:

```gdscript
var causou_dano: bool = personagem.receber_dano(10, global_position)
```

O retorno é `false` se o escudo bloqueou, se há invulnerabilidade após dano ou se a personagem não está viva. `tomar_dano(quantidade)` também continua disponível como alias.

Para um alvo receber dano do ataque de Ophelia:

```gdscript
func receber_dano(quantidade: int) -> bool:
	vida -= quantidade
	return true
```

O resolvedor também aceita `tomar_dano`. O ataque normal aplica no máximo uma vez por alvo a cada golpe; cada projétil aplica uma vez por lançamento.

Para um projétil hostil, coloque sua área/corpo na camada 5 e use o grupo `projeteis_hostis`, ou implemente um método de bloqueio. O exemplo `testes/ProjetilHostilTeste.gd` mostra ambos. No contato com a personagem, ele chama a interface de dano; não altera o valor da vida diretamente.

Não há animação de morte inventada. `Vitalidade` emite `morreu`, para conectar posteriormente ao fluxo de derrota/reinício. O cenário de teste permite restaurar a vida com N.

### Camadas de física usadas pelo pacote

| Número da camada | Valor da máscara | Papel |
|---:|---:|---|
| 1 | 1 | Cenário e apoios. |
| 2 | 2 | Corpo da personagem. |
| 3 | 4 | Alvos dos ataques. |
| 5 | 16 | Projéteis hostis. |
| 7 | 64 | Áreas de interação. |
| 8 | 128 | Escudo. |

As máscaras podem ser adaptadas ao seu projeto. Se um inimigo existente usa outra camada, ajuste a máscara de dano do Lenco ou a camada do inimigo. O corpo da nova personagem usa a camada 2; configure detecção de inimigos para incluir essa camada. O sensor de interação também inclui a camada 1 por compatibilidade com as áreas antigas.

## 7. Catálogo e integrações preservadas

A personagem continua no grupo `jogador` e conserva métodos como `pode_usar`, `esta_em_uso`, `tocar_reacao`, `agradecer_ajuda`, `definir_chapeu` e `teletransportar`.

`definir_catalogo_completo(true)` informa que a coleta está completa e evita solicitar Irritada ao entrar na área anterior ao portal. O catálogo deve chamar esse método com o estado real quando for integrado. O padrão é `false`. O pacote não inventa os dados das flores nem a senha do portão.

Os identificadores de desbloqueio, como `AtaqueLenco` e `Planar`, são os mesmos. `exportar_estado()` e `importar_estado()` continuam sendo a interface para o sistema de salvamento, sem misturar o modo debug aos desbloqueios reais.

## 8. Validação e limites

O pacote foi executado em Godot **4.5.1**, com física real em modo headless. O projeto enviado declara Godot 4.7; a confirmação final nessa versão e a avaliação visual com suas imagens devem ser feitas no cenário de teste do seu projeto.

As artes não estavam anexadas, então o ambiente de teste usou imagens temporárias para conseguir carregar os caminhos e verificar a lógica. Essas imagens de teste não estão no ZIP e não substituem suas artes.

Para repetir os testes com o executável Godot disponível no terminal:

```powershell
godot --headless --fixed-fps 60 --path . --script res://ophelia/testes/ValidarOphelia.gd
```

Troque `godot` pelo caminho do seu executável se necessário. O relatório `testes/RESULTADOS.md` informa o conjunto validado. Os testes instanciam uma cena isolada, liberam habilidades apenas em debug e não salvam dados de progresso.

## 9. Retorno ao Player antigo

Os arquivos antigos permanecem onde estavam. Para voltar à versão antiga, use sua cena Player no cenário de jogo. Se também quiser restaurar os controles anteriores, feche o editor e recupere a cópia de `project.godot` criada pelo instalador.

Nenhum arquivo de arte original é modificado pelo pacote.
