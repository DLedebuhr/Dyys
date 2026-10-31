# OPHELIA

Documento de design do jogo

Versão 0.1 • 28 de outubro de 2026

## 1 Visão geral

OPHELIA é um jogo de plataforma 2D sobre uma fada colecionadora de flores que explora ruínas flutuantes para completar seu catálogo botânico. O jogador atravessa cenários ligados às quatro estações, enfrenta armadilhas e utiliza um lenço mágico adaptativo para alcançar espécies que ninguém conseguiu catalogar.

A aventura combina movimentação, combate e coleta com o cuidado necessário para preservar as flores encontradas. Escolher quando proteger uma espécie, gastar uma fruta ou estabelecer um ponto de retorno faz parte da jornada. A personalidade de Ophelia aparece em suas reações ao jogador, nas pausas da exploração e nas pequenas conquistas de seu catálogo.

### Ficha do projeto

| Campo | Definição |
| --- | --- |
| Nome | OPHELIA |
| Gênero | Plataforma 2D com exploração, combate e coleta botânica |
| Plataforma | Computador; sistemas operacionais e requisitos mínimos a definir |
| Controles | Teclado e mouse |
| Público pretendido | Pessoas a partir de 10 anos; classificação indicativa pretendida, ainda não formalizada |
| Direção visual | Arte vetorial estilizada e minimalista |
| Motor | Godot; projeto atualmente trabalhado na versão 4.7 |
| Modelo comercial | Compra única, com acesso à experiência completa |
| Distribuição pretendida | GitHub; forma de venda e entrega da versão paga a definir |
| Estrutura principal | Quatro níveis sazonais e uma flor final |
| Coleção prevista | Vinte flores sazonais e uma flor final, totalizando 21 registros |
| Duração e idiomas | A definir |

### Uso deste documento

Este GDD organiza a experiência pretendida, as regras dos sistemas e os conteúdos necessários para produção. Uma regra de design descreve o comportamento desejado; sua presença neste documento não significa que ela já esteja implementada no jogo. Valores provisórios e diferenças em relação ao protótipo estão identificados nas próprias seções.

## 2 Experiência e objetivos de design

O objetivo principal é proporcionar uma aventura estratégica e divertida em que a curiosidade de explorar acompanhe o desejo de completar uma coleção. O jogador deve perceber que as habilidades do lenço ampliam suas possibilidades de percurso e que preservar uma flor encontrada pode ser tão importante quanto alcançá-la.

A exploração deve recompensar a observação do cenário. Flores, pontos de apoio e caminhos alternativos precisam ter leitura suficiente para convidar o jogador a investigar, sem depender de tentativa e erro para toda descoberta. A quantidade de rotas opcionais e o grau de liberdade dentro de cada nível ainda precisam ser definidos.

O lenço é o principal instrumento de ação. Suas habilidades devem compartilhar uma identidade visual reconhecível, mas apresentar funções claras: cortar, lançar projéteis, defender, planar, agarrar e impulsionar. O aprendizado progressivo deve permitir que o jogador compreenda cada habilidade antes de precisar combiná-la com outras.

A coleção dá continuidade às conquistas. Cada flor catalogada registra uma etapa da aventura, enquanto o inventário limitado e as consequências da morte introduzem decisões sobre o que carregar e quando preservar os espécimes.

Ophelia também deve se comunicar pelo corpo. Irritação, agradecimento, cansaço e dança aproximam a personagem do jogador e tornam os momentos de espera parte da apresentação do jogo.

## 3 História e ambientação

### Premissa narrativa

Ophelia é uma fada que dedica seu tempo a colecionar flores. Sua maior ambição é criar o catálogo botânico mais completo que qualquer ser já tenha visto. Para avançar nesse objetivo, ela decide explorar as ruínas flutuantes de [nome a definir], um lugar antigo conhecido por abrigar espécimes únicos e por repelir quem tenta alcançar seu topo.

Há milhares de anos, as ruínas acumulam histórias de visitantes que partiram sem concluir a travessia. Seus caminhos e mecanismos de defesa fizeram do lugar uma ameaça para forasteiros. Entre essas defesas, a mais temida é a anulação da magia natural de qualquer ser que não pertença àquele domínio. Para uma comunidade de fadas acostumada a depender das próprias asas, essa restrição tornou a exploração especialmente difícil.

Ophelia conhece as histórias, mas não aceita que elas determinem até onde pode chegar. Antes de partir, dedica muitas noites à criação de um lenço adaptativo, desenvolvido com runas naturais. Semissenciente, o tecido responde às situações da viagem e aprende novas formas de ajudá-la. Sua primeira função foi servir de gancho; ao longo da aventura, ele amplia suas capacidades para acompanhar os desafios encontrados.

A jornada de Ophelia nasce de um objetivo pessoal: encontrar, preservar e registrar as flores das ruínas. A subida também coloca sua determinação à prova, exigindo que ela reconheça os riscos de continuar e aprenda a trabalhar com os recursos que preparou.

### Regras do mundo que precisam de definição

É necessário explicar por que as runas do lenço e a magia antiga do chapéu continuam funcionando em um lugar que anula a magia natural. Essa distinção deve sustentar as mecânicas, especialmente a planagem, o aprendizado de habilidades e o retorno pelo chapéu.

A origem das ruínas, a razão de suas defesas e a existência de habitantes ou guardiões ainda não foram descritas. Também faltam a identidade da flor final e a resolução da história ao completar o catálogo.

Como sugestões de nome, sem decisão definitiva, o lugar pode ser chamado de Ruínas de Astéria, Jardins Suspensos de Elaris ou Ruínas Flutuantes de Aurélia. A escolha deve acompanhar o tom da história e os nomes usados no restante do mundo.

## 4 Ophelia e seus equipamentos

### Personalidade

Ophelia é motivada e ambiciosa. Quando escolhe um objetivo, insiste em encontrar uma maneira de alcançá-lo, mesmo diante de histórias que desencorajariam outros exploradores. Sua determinação convive com um temperamento forte: ela se irrita quando os planos não saem como esperava e demonstra essa frustração sem muita cerimônia.

Essa impaciência não elimina seu lado alegre. Ophelia reconhece quem a ajuda e compartilha a satisfação de avançar em seu catálogo. A relação com o jogador aparece nessas respostas: ela pode agradecer uma descoberta, cobrar atenção ou se distrair enquanto espera pela próxima ação.

### Bolsa de coleta

A bolsa acompanha Ophelia em todas as aventuras. Maior por dentro do que sua aparência sugere, ela permite transportar os materiais e espécimes encontrados pelo caminho. Em termos de jogo, está associada ao inventário de 14 espaços, cuja capacidade limitada exige administrar o que será levado.

### Poncho

O poncho grande protege a personagem e ajuda a definir sua silhueta. Ophelia passou a utilizá-lo depois de uma tentativa de roubo de sua bolsa em uma aventura anterior. O episódio explica uma escolha visual da personagem, mas ainda não estabelece uma função mecânica específica para o poncho.

### Chapéu de família

O chapéu foi passado de geração em geração e guarda magia antiga costurada em cada ponto. Sua habilidade central funciona como uma cápsula temporal: ao deixá-lo em um local, Ophelia estabelece o lugar para onde poderá retornar depois da morte.

O jogador decide entre continuar usando o chapéu ou deixá-lo como ponto de retorno. O visual da personagem acompanha essa escolha, utilizando variações de animação com e sem chapéu. Regras de posicionamento, recolhimento e restrições do objeto ainda precisam ser detalhadas.

### Lenço adaptativo

O lenço foi desenvolvido por Ophelia após muitas horas de trabalho e noites de sono sacrificadas. Ele possui comportamento semissenciente e aprende maneiras de responder às dificuldades da exploração. Seu movimento contínuo e suas duas fitas fazem parte da identidade da personagem, inclusive quando ela está parada.

O tecido começou como um gancho. A relação entre essa origem narrativa e as habilidades disponíveis no início da partida ainda precisa ser confirmada: o GDD não determina, por enquanto, se o gancho já estará disponível antes do primeiro ataque.

## 5 Estrutura da aventura e progressão

### Níveis sazonais

A aventura principal possui quatro níveis, associados ao Verão, Outono, Inverno e Primavera. Cada um contém cinco flores que precisam ser encontradas para permitir o avanço. A ordem definitiva de visita às estações ainda não foi estabelecida; a sequência em que aparecem neste documento organiza os conteúdos, sem fixar a ordem da campanha.

Os níveis fazem parte da exploração das ruínas flutuantes. A identidade visual de cada estação deve ajudar a reconhecer o ambiente e suas flores, enquanto a distribuição de obstáculos introduz oportunidades de usar o lenço. O tamanho dos níveis, sua divisão em trechos e os tipos de armadilha de cada estação permanecem em aberto.

### Ciclo principal de jogo

O jogador explora uma área, identifica um caminho para alcançar uma flor e utiliza movimento ou habilidades para atravessá-lo. Ao coletar o espécime, administra o espaço da bolsa e os materiais necessários para preservá-lo. A flor pode então ser encapsulada e catalogada, contribuindo para a conclusão da coleção da estação.

Depois de reunir as cinco flores exigidas, o jogador se dirige ao portão para avançar. Ao longo do percurso, também encontra recursos de cura, materiais de fabricação e interativos que ensinam habilidades ou aumentam a vida máxima.

### Condição de avanço

A regra já definida exige as cinco flores da estação para concluir o nível. Falta decidir se o portão verifica flores carregadas, flores encapsuladas ou registros permanentes no catálogo. Essa escolha altera a relação entre morte, inventário e progressão e deve ser resolvida antes da implementação definitiva do portão.

Quando Ophelia chega ao portão sem cumprir o requisito, ela reage com irritação voltada ao jogador. A interface ou o próprio portão também precisará informar quais flores faltam; a forma dessa indicação ainda será definida.

### Conclusão da aventura

O catálogo reserva um registro adicional para uma flor final, além das vinte flores sazonais. Sua localização, a forma de obtê-la e a condição de encerramento do jogo ainda precisam ser descritas. Não está definido se ela pertence a uma área própria, ao topo das ruínas ou a uma etapa dentro do último nível.

## 6 Movimentação e câmera

Ophelia pode andar, correr e pular. A movimentação deve responder ao comando do jogador com transições que preservem a leitura da personagem. O protótipo utiliza assistência para pulos próximos à borda e para comandos feitos pouco antes de tocar o chão; os valores finais desses ajustes ainda pertencem ao balanceamento.

As habilidades de planagem, gancho e propulsão ampliam essa movimentação. A intenção é permitir que o jogador combine as ferramentas aprendidas para superar distâncias e obstáculos, respeitando as limitações de cada uma.

Ao levantar depois de sentar por inatividade, a personagem deve concluir uma transição curta antes de começar a andar, evitando deslizar sentada. O pulo recebe prioridade para manter uma resposta rápida. A duração de 0,22 segundo foi proposta no refinamento do protótipo e ainda depende de validação na cena final.

A câmera acompanha Ophelia suavemente e respeita os limites definidos para cada cenário. Ela deve manter o percurso legível sem revelar áreas além do mapa. É organizada como uma cena independente, permitindo ajustar acompanhamento, enquadramento e limites por fase.

A HUD permanece fixa na tela e não acompanha os movimentos do cenário. A câmera e a interface devem ser organizadas separadamente para permitir que telas sobrepostas, como a ajuda de habilidades, apareçam acima da ação.

### Comandos

| Ação | Controle registrado ou situação |
| --- | --- |
| Andar para a esquerda e direita | A e D |
| Pular | W no mapeamento trabalhado; confirmar configuração final |
| Mirar habilidades direcionais | Posição do mouse |
| Interagir | F |
| Abrir inventário | I |
| Pausar | Esc |
| Usar fruta | Ação ControleUsarFruta; R sugerido para teste |
| Ataques, defesa, gancho, propulsão e corrida | Consolidar as teclas finais no Mapa de Entrada |

Os comandos discretos, como iniciar um ataque ou interagir, devem responder ao pressionamento da tecla, sem disparar repetidamente por ela permanecer segurada. Ações contínuas, como caminhar ou manter uma planagem configurada para segurar, seguem a duração do comando. As letras não devem ser fixadas nos nomes das funções ou espalhadas pelos sistemas: o Mapa de Entrada concentra essa configuração.

## 7 Habilidades do lenço

### Aprendizado progressivo

O jogador só pode utilizar as habilidades que Ophelia já aprendeu. Cada interativo de aprendizado está associado a uma habilidade específica e pode ser configurado para diferentes pontos da campanha. A ordem de desbloqueio, os locais dos interativos e eventuais dependências entre habilidades ainda precisam de uma lista definitiva.

Antes da interação, o objeto apresenta um símbolo flutuante envolvido em luz. A intensidade deve crescer conforme Ophelia se aproxima. Ao pressionar F, essa luz se contrai para o centro, formando uma pequena esfera. A esfera segue rapidamente em linha reta até o ponto do lenço e parece ser absorvida por ele.

Depois da absorção, a luz percorre as fitas e produz brilhos e ecos nas pontas. O lenço mantém seu movimento de repouso durante essa apresentação; ele não desenha o ataque nem causa dano. A sequência termina com a abertura da tela de ajuda correspondente.

### Corte de Cetim

Corte de Cetim é o ataque normal do lenço. O tecido executa um golpe direcionado para atingir alvos e obstáculos que aceitam dano. O dano definido para esse ataque é de 10 pontos.

A direção acompanha a mira do jogador e deve ser comunicada pela animação das fitas. Alcance, duração do golpe e intervalo entre ataques ainda precisam de valores finais. A existência de inimigos específicos e suas reações ao impacto também permanece em aberto.

### Projéteis de Cetim

Projéteis de Cetim é uma melhoria posterior, separada do ataque normal. Ela disponibiliza dois disparos, cada um com 5 pontos de dano. O disparo lança um projétil na direção do mouse, sem fazer desaparecer a ponta original do lenço.

Ao parar no cenário, o projétil permanece no local por até 5 segundos. Durante esse período, ele serve como ponto de apoio para o gancho. Se Ophelia alcançá-lo antes do fim da espera, ele retorna antecipadamente; caso contrário, retorna ao terminar o intervalo, recuperando o disparo disponível.

A textura do projétil deve ser configurável. O brilho de sua ponta deve repetir sua silhueta, como um eco do próprio desenho, em vez de formar um disco genérico. A interação de um projétil que está sendo usado pelo gancho quando seu tempo termina ainda exige conferência e definição explícita para o jogador.

### Casulo de Cetim

Casulo de Cetim é a defesa. As duas fitas formam um círculo ao redor de Ophelia, mantendo o trajeto de cada arco e ultrapassando ligeiramente o ponto de encontro para produzir um fechamento natural. O desenho deve ser circular e evitar a aparência de coração observada em versões anteriores.

A proteção existe apenas durante a janela ativa da habilidade. Seu efeito visual pode continuar por mais tempo para suavizar o desaparecimento, sem prolongar a proteção real. As armadilhas podem ser configuradas para aceitar o bloqueio do escudo ou ignorá-lo.

Tempo de formação, duração da defesa efetiva e recarga precisam de balanceamento final. A orientação do desenho acompanha a direção definida ao iniciar a defesa; a apresentação não deve mudar de lado abruptamente no meio da animação.

### Brisa

Brisa permite planar durante a queda, reduzindo a velocidade de descida e ampliando as possibilidades de travessia. A habilidade deve ter uma apresentação compatível com o bloqueio da magia natural presente nas ruínas.

Ainda precisam ser definidos a velocidade final de queda, o tempo máximo de uso, a existência de algum recurso consumido e se o comando definitivo será mantido pressionado ou alternado por toque. O protótipo admite configuração de uso ao segurar.

### Laço de Cetim

Laço de Cetim permite prender o lenço a pontos de apoio e objetos válidos. A mecânica inclui a utilização dos projéteis estacionados como âncoras temporárias. O sistema trabalhado diferencia a interação com apoios firmes e objetos leves, mas a lista de objetos permitidos e suas regras finais ainda precisa ser consolidada.

O alcance, a seleção de alvos, a soltura e os limites de balanço devem ser apresentados de forma legível. A habilidade deve ajudar o jogador a compreender onde pode se prender antes de depender dela em uma travessia arriscada.

### Sopro de Cetim

Sopro de Cetim produz um impulso aéreo estilizado como uma propulsão do lenço. As fitas se orientam para o mouse e realizam o golpe nessa direção; a reação impulsiona Ophelia no sentido contrário. O efeito acompanha esse movimento, com destaque na ponta e sem uma segunda explosão desnecessária na origem.

A função é semelhante a uma oportunidade adicional de salto no ar. O comportamento trabalhado permite um uso aéreo, recuperado ao tocar o chão. Força, duração e condições adicionais de bloqueio precisam ser confirmadas no balanceamento final.

### Valores já registrados

| Habilidade | Valor ou regra definida | Valores ainda pendentes |
| --- | --- | --- |
| Corte de Cetim | 10 de dano | Alcance, tempos e recarga |
| Projéteis de Cetim | 2 disparos; 5 de dano por projétil; espera de até 5 s | Velocidade, alcance e situação de âncora ocupada |
| Casulo de Cetim | Defesa circular; efeito pode durar além da proteção | Formação, proteção ativa e recarga |
| Brisa | Redução da queda durante planagem | Velocidade, duração e comando final |
| Laço de Cetim | Apoios, objetos válidos e projéteis como âncora | Alcance e regras por tipo de alvo |
| Sopro de Cetim | Impulso contrário à mira; um uso aéreo no comportamento trabalhado | Intensidade e duração |

## 8 Animações e relação com o jogador

### Repouso de lado e sentar

Quando Ophelia permanece sem receber ações por 10 segundos enquanto está de lado, ela demonstra cansaço de esperar e se senta no chão. Ao voltar a receber um comando de movimento, levanta antes de começar a caminhar. O jogador também pode interromper essa espera com pulo, conforme a prioridade da movimentação.

A intenção atual é usar 10 segundos. O código anteriormente trabalhado continha um temporizador de repouso lateral de 20 segundos; esse valor deve ser atualizado ou confirmado na revisão das métricas.

### Irritação no portão

Ao chegar ao portão sem as cinco flores exigidas, Ophelia se volta para o jogador e executa uma reação de irritação. A mudança de orientação passa pela animação de transição, espelhada conforme o lado de origem, evitando uma troca brusca de pose.

### Agradecimento

Ao catalogar uma flor, Ophelia agradece ao jogador pela ajuda em seu objetivo. A reação utiliza a mesma lógica de transição para a frente. Sua duração e o momento exato em que ocorre em relação ao fechamento do inventário ainda precisam ser confirmados.

### Espera frontal e dança

Depois da irritação ou do agradecimento, Ophelia permanece de frente para o jogador. Essa pose corresponde ao estado de esperar movimento. Se não houver uma ação nos 10 segundos seguintes, ela inicia a animação de espera frontal, descrita neste GDD como dança.

Ao receber uma ação, ela realiza a transição de volta à orientação de jogo e retoma o comportamento apropriado. A dança não deve substituir o agradecimento antes de sua conclusão nem acontecer imediatamente depois dele.

### Variações visuais

As animações precisam respeitar as versões com e sem chapéu e a orientação lateral quando aplicável. O encaixe do lenço deve acompanhar o corpo durante sentar e levantar, sem se deslocar de forma independente da gola. A velocidade das transições será ajustada para manter resposta ao comando e continuidade visual.

## 9 Vida e recuperação

### Pontos de vida e dano

Ophelia inicia com 3 pontos de vida. Partindo da vida completa, três golpes de 1 ponto provocam a morte no terceiro, desde que os golpes sejam separados pelo intervalo de invulnerabilidade e não haja recuperação entre eles.

Cada armadilha define seu próprio dano. Um perigo pode retirar 1 ponto, enquanto outro retira 2; o valor pertence à configuração daquela instância. No protótipo de teste, também são aceitos passos de meia vida.

Depois de receber dano, Ophelia fica temporariamente invulnerável. O valor inicial preparado para teste é de 1 segundo. Durante esse intervalo, a personagem pisca. O impacto também produz perda de pequenos brilhos e uma tremida visual curta, sem deslocar sua colisão nem desrespeitar os limites da câmera.

### Cura com frutas

Cada fruta recupera meia vida. Existe uma fruta visualmente distinta para cada estação, mas todas possuem o mesmo efeito de cura. Os nomes e os desenhos dessas quatro frutas ainda não foram informados.

A vida nunca pode ultrapassar o máximo atual. Uma fruta só é consumida quando seu uso realmente recupera vida; não deve ser gasta com a vida cheia, sem estoque ou após a morte. A integração definitiva será feita com o inventário. O sistema provisório mantém três frutas de cada estação apenas para teste.

Ao recuperar vida, partículas de cura surgem ao redor da personagem. A referência visual utiliza pequenos símbolos e brilhos verdes subindo, sem plataforma no chão e sem coluna de luz. A HUD responde ao mesmo evento de cura.

### Regeneração automática

A duração de produção definida é de 5 minutos por vida inteira. Para testes, o intervalo foi reduzido para 30 segundos. O protótipo preparado recupera uma vida por vez, completando primeiro uma vida parcial; nessa regra, meia vida exige metade do intervalo.

A implementação provisória reinicia a contagem ao receber novo dano ou cura e pausa o relógio quando o jogo está pausado. Essas escolhas de sequência e reinício ainda precisam ser confirmadas como regras definitivas de design. A regeneração nunca ressuscita uma personagem morta.

### Vida máxima adicional

Interativos específicos permitem adquirir mais um ponto de vida máxima por instância utilizada, até o limite de 6. O funcionamento segue a aproximação e interação utilizadas nos objetos de aprendizado. No protótipo preparado, o novo espaço já surge preenchido, sem curar os espaços antigos que estiverem vazios.

A distribuição desses interativos pelos quatro níveis, sua aparência definitiva e qualquer condição adicional para coletá-los ainda precisam ser definidas.

### Indicador de vida

A HUD possui uma decoração de base, com três indicadores inicialmente disponíveis. Cada indicador representa uma vida inteira e precisa comunicar também meia vida. Ao perder vida, o preenchimento correspondente desaparece com uma explosão de partículas.

Quando a regeneração se aproxima do fim, um brilho antecipa a recuperação. Ao completar o intervalo ou utilizar uma fruta, o espaço recuperado reaparece e reage visualmente. Novas vidas máximas revelam indicadores adicionais até seis, respeitando as posições previstas na decoração.

## 10 Morte e pontos de retorno

### Apresentação da morte

Quando a vida chega a zero, Ophelia se desfaz em uma explosão de partículas. A personagem deixa de receber comandos e de executar ataques durante a sequência. Depois, reaparece no ponto de retorno válido com a vida recuperada, conforme a regra provisória preparada.

A versão de teste retorna ao início do nível após aproximadamente 1,4 segundo, sem recarregar toda a fase. O sistema definitivo deve consultar o chapéu antes de decidir o destino.

### Chapéu como checkpoint

O chapéu estabelece um ponto de retorno quando é deixado no cenário. Se Ophelia morrer enquanto o objeto estiver posicionado, renasce onde ele está. Se estiver usando o chapéu, sem deixá-lo em nenhum lugar, renasce no início do nível.

Esse ponto de retorno é uma regra do mundo de jogo. Ele ainda não define, sozinho, quando o progresso é gravado em disco ou como um dos quatro slots de partida é atualizado. A relação entre checkpoint e gravação deve ser detalhada para que sair do jogo e morrer não produzam comportamentos contraditórios.

É preciso definir onde o chapéu pode ser deixado, como é recolhido, se reaparece equipado após o retorno e o que acontece quando a posição escolhida se torna perigosa ou inacessível.

### Consequências sobre os itens

| Item ou estado | Consequência prevista da morte |
| --- | --- |
| Flores não encapsuladas | Quebram e são perdidas |
| Cápsulas | Quebram e são perdidas; confirmar inclusão das cápsulas com seiva |
| Ramos | Ficam flutuando no local da morte por cerca de 10 minutos |
| Frutas | Ficam flutuando no local da morte por cerca de 10 minutos |
| Flores encapsuladas | Não são afetadas pela morte |
| Registros do catálogo | Persistência e relação com perdas a confirmar |

Ramos e frutas deixados no local da morte podem ser recuperados antes de desaparecer. A contagem precisa de uma regra final: ainda não está definido se continua com o jogo pausado, fora do nível ou após encerrar a partida. Também falta estabelecer o comportamento de várias mortes consecutivas e de pontos de queda inacessíveis.

Essas perdas ainda não fazem parte do protótipo de vida preparado. Na versão de teste, o estoque provisório e os interativos usados permanecem durante o retorno, sem simular descarte de itens.

## 11 Itens e inventário

### Estrutura do inventário

O inventário é aberto pela tecla I e apresenta três áreas: armazenamento, descrição do item selecionado e oficina. A partir dele, o jogador também acessa o progresso da aventura e o catálogo.

O armazenamento possui 14 espaços compartilhados entre frutas, flores, ramos e cápsulas. Como alguns itens ocupam espaços individuais, a fabricação e a preservação de flores também alteram a maneira de administrar a bolsa.

### Acúmulo de itens

| Categoria | Regra de armazenamento |
| --- | --- |
| Frutas da mesma estação | Acumulam no mesmo espaço |
| Frutas de estações diferentes | Usam pilhas distintas |
| Ramos | Acumulam no mesmo espaço |
| Flores repetidas da mesma espécie | Acumulam no mesmo espaço |
| Flores de espécies diferentes | Usam espaços ou pilhas distintos |
| Cápsulas vazias | Não acumulam; uma por espaço |
| Cápsulas com seiva | Não acumulam; uma por espaço |
| Flores encapsuladas | Não acumulam; uma por espaço |

Os limites de quantidade por pilha ainda não foram definidos. Também falta determinar como o jogo responde ao tentar coletar um item com a bolsa cheia e se haverá descarte ou troca de posição por arrastar.

### Descrição do item selecionado

A segunda área apresenta o nome e uma breve explicação do objeto selecionado. O texto deve orientar o jogador sobre uso, preservação ou combinação, evitando depender apenas de ícones para comunicar o funcionamento da oficina.

### Oficina

A oficina permite combinar materiais para produzir um novo item. Duas unidades de ramo formam uma cápsula. Uma cápsula com seiva e uma flor formam uma flor encapsulada. A flor encapsulada pode então ser catalogada.

A etapa entre obter uma cápsula vazia e possuir uma cápsula com seiva ainda não foi descrita. É necessário definir a origem da seiva e a ação usada para encher a cápsula. Catalogar é uma ação sobre o item preservado, e não necessariamente uma combinação de dois objetos.

| Ação | Materiais ou requisito | Resultado |
| --- | --- | --- |
| Montar cápsula | 2 ramos | 1 cápsula vazia |
| Preparar cápsula com seiva | Procedimento a definir | 1 cápsula com seiva |
| Encapsular flor | 1 cápsula com seiva e 1 flor | 1 flor encapsulada |
| Catalogar | 1 flor encapsulada | Registro correspondente; destino do item a confirmar |

A confirmação de fabricação deve consumir materiais somente quando a operação puder ser concluída. Ainda falta decidir se existe tempo de execução, animação própria ou restrição para fabricar durante situações de perigo.

## 12 Flores e catálogo botânico

### Função das flores

As flores são o objetivo central da aventura. Cada uma representa uma descoberta a alcançar, um espécime a preservar e uma entrada possível no catálogo. A progressão precisa conectar esses três momentos de forma compreensível, para que o jogador saiba quando uma espécie está apenas na bolsa e quando sua conquista já está registrada.

Cada estação possui cinco espécies selecionadas. O catálogo reserva 21 posições fixas: cinco por estação e uma para a flor final. A ordem dos registros é automática e não pode ser reorganizada pelo jogador.

### Espécies selecionadas

| Estação | Flores |
| --- | --- |
| Verão | Calla, Lavanda, Cosmos, Lótus e Lírio |
| Outono | Viola, Cólquico, Princesa, Azaleia e Dália |
| Inverno | Heléboro, Ciclame, Camélia, Prímula e Floco de Neve |
| Primavera | Tulipa, Muguet, Íris, Narciso e Sakura |
| Flor final | Nome, características e localização a definir |

Os nomes foram mantidos conforme a seleção do projeto. As características botânicas e visuais de cada flor ainda precisam ser fornecidas. Quando um nome comum admitir mais de uma interpretação, a referência visual ou a identificação escolhida deve acompanhar a ficha para evitar desenhos inconsistentes.

### Ficha de produção para cada flor

Cada espécie deve possuir uma ficha com nome de exibição, estação, características escolhidas e função no percurso. A ficha também deve indicar a localização prevista, a maneira de coleta e qualquer requisito de habilidade para alcançá-la.

Os recursos visuais necessários são o sprite da flor no cenário e suas variações, o sprite encapsulado e o ícone do inventário. A apresentação no catálogo pode reutilizar uma dessas artes ou receber ilustração própria; essa escolha ainda está aberta.

A conclusão do nível deve usar o mesmo identificador de espécie adotado no inventário e no catálogo. Isso permite distinguir cinco espécies diferentes de cinco exemplares repetidos da mesma flor.

### Catálogo e duplicatas

Ao catalogar uma flor válida, o registro correspondente aparece em sua posição fixa. A animação de agradecimento acompanha essa conquista. Falta definir se catalogar consome a flor encapsulada, se o exemplar permanece na bolsa e o que pode ser feito com espécies já registradas.

## 13 Interface e navegação

### Organização geral

A interface deve apresentar as ações do jogo com imagens coerentes com a direção vetorial e minimalista. Telas de consulta precisam manter uma organização previsível para que inventário, progresso e catálogo possam ser acessados sem o jogador perder a referência de onde está.

O fluxo confirmado começa no menu principal, que oferece Iniciar, Ajustes e Sair. Iniciar leva à seleção de saves. Ajustes se divide em Volume e Controles. Durante a partida, I abre o inventário e Esc abre a pausa. Inventário, progresso e catálogo possuem navegação entre si.

O conteúdo completo da pausa e as regras de fechar cada tela ainda precisam ser definidos. Retornos convencionais para a tela anterior são recomendados, mas não constituem uma lista final de botões neste rascunho.

### Menu principal

É a primeira tela apresentada ao jogador. Exibe o nome OPHELIA e três opções: Iniciar, Ajustes e Sair. O fundo, as animações de ambientação e a transição para cada opção ainda precisam de especificação visual.

### Ajustes e volume

A tela de ajustes permite acessar Volume e Controles. Em Volume, o jogador altera o volume geral, o da música e o dos efeitos sonoros. Intervalos, valores iniciais, opção de silenciar e persistência dessas preferências ainda devem ser registrados.

### Controles

A tela apresenta uma imagem de teclado e mouse com as teclas e os botões utilizados em destaque. Ao passar o cursor sobre um destaque, o jogador recebe uma frase curta explicando sua função. Ainda não está definido se essa tela apenas consulta o mapeamento ou permite remapear comandos.

### Seleção de partida

A tela Iniciar contém até quatro slots de save. Cada slot é representado por um vaso de flores. Conforme o progresso daquela partida, o vaso recebe novas flores, variando de zero a seis.

Ainda falta estabelecer quais marcos correspondem a cada flor do vaso e quais informações acompanham o slot, como nome, tempo jogado ou estação atual. Também devem ser definidas as ações para criar, continuar, apagar e eventualmente sobrescrever uma partida.

### Pausa

A tela de pausa é acessada por Esc. Sua composição e suas opções não foram detalhadas. É necessário decidir se ela oferece retorno à partida, ajustes, saída ao menu e outras ações, além de confirmar quais sistemas deixam de avançar enquanto estiver aberta.

### Inventário

A tela organiza os 14 espaços de armazenamento, o painel descritivo e a oficina. Deve permitir identificar rapidamente quantidades, estados das cápsulas e flores já preservadas. Acesso por I e navegação para progresso e catálogo já estão previstos.

### Progresso

A tela de progresso apresenta uma espiral alongada com marcadores que identificam o início dos níveis. Um ícone avança ao longo dela conforme a jornada progride, ajudando o jogador a compreender sua posição e o quanto falta para concluir a aventura.

A medida usada por esse avanço ainda não foi definida. Pode depender de trechos do nível, marcos narrativos ou outro critério, mas a escolha precisa ser única e consistente. A tela oferece acesso ao inventário e ao catálogo.

### Catálogo

A tela exibe as 21 posições fixas da coleção. Cada flor é associada automaticamente ao lugar correto, sem permitir rearranjo. É necessário decidir como aparecem registros ainda vazios, quais descrições acompanham os espécimes e como a flor final é revelada. A tela permite acessar inventário e progresso.

### Ajuda de habilidade

Depois de aprender uma habilidade, o jogador recebe uma tela de ajuda sobreposta à partida. O cenário continua visível atrás de um fundo com transparência. A apresentação não troca a cena principal por uma tela desconectada da ação.

A configuração atual separa a cor de fundo, uma imagem com os elementos explicativos e um vídeo de demonstração. Cada habilidade possui seus próprios elementos e vídeo. O botão de fechar utiliza o padrão visual e sonoro dos botões do jogo.

A entrada deve parecer surgir do centro para as bordas, com escala e transparência suaves, sem deslocamento vertical a partir de baixo. A demonstração mantém seu enquadramento e posição. No fluxo trabalhado, o aprendizado e a ajuda pausam a ação para permitir leitura.

### Padrão de botões

Os botões utilizam texturas para os estados normal, destacado pelo cursor e pressionado. O destaque pode aumentar levemente a escala, acompanhado de som de passagem do mouse. O clique produz um retorno visual curto e um som próprio. Esse comportamento deve ser consistente entre as telas.

## 14 Direção de arte e animação

A direção visual utiliza desenhos vetoriais estilizados e uma composição minimalista. A silhueta de Ophelia, marcada pelo poncho, chapéu, bolsa e lenço, deve permanecer reconhecível durante deslocamentos, efeitos e transições de pose.

A arte precisa diferenciar as quatro estações e ajudar a localizar elementos interativos. As paletas de Ophelia, Verão, Outono, Inverno e Primavera ainda serão inseridas. Também falta definir a paleta comum da interface e as cores usadas para dano, cura, objetos de aprendizado e catálogo.

Os efeitos devem reforçar a ação sem esconder plataformas ou a direção do movimento. Ataques, defesa, propulsão, aprendizado e cura compartilham brilhos e ecos compatíveis com o tecido, mas precisam de ritmo e forma próprios para não serem confundidos.

Para o projétil, o eco repete o desenho de sua ponta. Na defesa, o círculo preserva o movimento dos arcos. No aprendizado, a luz é absorvida antes de percorrer o lenço. Na cura, pequenos símbolos e pontos sobem ao redor do corpo. A morte utiliza uma explosão maior que sinaliza a perda de controle antes do retorno.

### Relação inicial de recursos visuais

| Grupo | Conteúdos a reunir ou confirmar |
| --- | --- |
| Ophelia | Model sheet, proporções, sprites base, versões com e sem chapéu |
| Animações | Repouso, andar, correr, pular, sentar, levantar, transição, irritação, agradecimento e dança |
| Lenço | Fitas, pontas, textura de projétil e referências das seis habilidades |
| Flores | Arte no cenário, variações, encapsulamento e ícones das vinte espécies e da flor final |
| Recursos | Quatro frutas sazonais, ramos, cápsula vazia e cápsula com seiva |
| Cenários | Blocos e composição das ruínas, quatro estações, portões, armadilhas e pontos de apoio |
| Interface | Logo, botões, decoração da vida, seis indicadores, inventário, oficina, catálogo, progresso e vasos de save |
| Demonstrações | Imagem explicativa e vídeo próprios para cada habilidade |

## 15 Áudio e comunicação das ações

O jogo prevê controles separados para volume geral, música e efeitos. Os botões já possuem comportamento previsto para sons de destaque e clique. O restante da direção sonora ainda precisa ser definido.

A lista de produção deve contemplar movimento, uso das habilidades, impacto bloqueado, dano, cura, morte, coleta, fabricação, catalogação, ativação do chapéu e aprendizado. Ainda não há decisões sobre instrumentos, temas por estação, sons ambientes ou uso de voz.

Como recomendação de design, informações importantes devem possuir resposta visual além de som. A confirmação de cura, a indisponibilidade de uma habilidade e o requisito incompleto do portão precisam continuar compreensíveis quando os efeitos sonoros estiverem reduzidos.

## 16 Tecnologia e organização de produção

O jogo é desenvolvido no Godot para computador, com controles por teclado e mouse. O projeto utiliza cenas e scripts separados para organizar personagem, habilidades, efeitos e interface. A configuração dos comandos deve permanecer centralizada no Mapa de Entrada.

A personagem OPHELIA concentra a coordenação do movimento e utiliza componentes para tarefas específicas. A câmera funciona em cena própria, com limites configurados por fase. A HUD utiliza uma camada de interface independente e as ajudas aparecem acima dela.

Os nomes de pastas e sistemas devem ser fáceis de identificar, seguindo a preferência por termos como Combate, Efeitos e Interface. Alterações de caminho precisam preservar ou atualizar as referências do projeto; reorganização técnica não deve modificar regras de jogo sem uma decisão de design correspondente.

Os vídeos de demonstração utilizam o formato aceito pelo reprodutor configurado no projeto; o fluxo atual foi preparado para arquivos OGV com vídeo Theora. Os arquivos de arte vetorial de origem, os formatos exportados e os critérios de resolução ainda devem ser documentados na etapa de produção.

### Situação dos principais sistemas

| Sistema | Situação registrada |
| --- | --- |
| Movimento, reações e lenço | Trabalhados no protótipo; métricas e integração final ainda exigem revisão |
| Câmera | Script e montagem definidos para acompanhamento suave com limites |
| Aprendizado e ajuda de habilidades | Fluxo e configuração por habilidade trabalhados; conteúdo visual depende dos materiais de cada uma |
| Vida, cura, HUD e retorno ao início | Componentes preparados e verificados em cena de validação; integração com a cena atual ainda pendente |
| Inventário e oficina | Regras descritas; integração com vida ainda pendente |
| Chapéu como checkpoint | Conceito definido; comportamento completo e implementação pendentes |
| Perdas de itens na morte | Regras iniciais descritas; implementação pendente |
| Saves e catálogo permanente | Estrutura desejada descrita; formato e momento de gravação pendentes |
| Métricas finais e balanceamento | Pendentes |

## 17 Critérios de validação

A movimentação deve permitir andar, pular e usar habilidades sem comandos involuntários durante transições. Sentar e levantar não podem produzir deslizamento indevido; a dança frontal só começa depois da espera e de a reação anterior terminar.

Cada habilidade precisa ser testada antes e depois do desbloqueio. Uma habilidade não aprendida não pode ser executada em uma partida normal. Os dois projéteis devem respeitar dano, disponibilidade, retorno e função de âncora sem remover a ponta do lenço.

O sistema de vida deve demonstrar a morte no terceiro golpe de um ponto a partir de três vidas completas, respeitando a invulnerabilidade. Frutas curam meia vida, só são gastas com efeito real e não ultrapassam o máximo. A HUD acompanha dano, cura e crescimento até seis.

O inventário precisa respeitar 14 espaços, diferenciar pilhas por espécie e estado e consumir os materiais corretos ao fabricar. A falta de espaço não pode causar perda silenciosa de objetos. Uma operação incompleta não deve gastar materiais.

A conclusão de um nível deve exigir cinco espécies válidas segundo a regra de portão escolhida. Cinco cópias da mesma flor não podem substituir cinco espécies diferentes. O catálogo precisa mapear os vinte registros sazonais e o registro final sem duplicar posições.

O retorno após a morte deve considerar a posição válida do chapéu. As perdas e a recuperação de itens devem obedecer ao tempo estabelecido, inclusive em mortes consecutivas. Sair e carregar uma partida deve preservar exatamente os dados definidos para o save.

## 18 Informações necessárias para completar o GDD

### Prioridade para fechar as regras principais

1. Qual é o nome definitivo das ruínas e por que lenço e chapéu funcionam onde a magia natural é anulada?
2. Qual é a ordem dos quatro níveis? Existe uma área final além deles?
3. Qual é a flor final e o que acontece quando ela é catalogada?
4. O portão exige flores na bolsa, flores encapsuladas ou espécies já registradas no catálogo?
5. Catalogar consome o exemplar encapsulado? O registro permanece após a morte? Qual é a utilidade das duplicatas?
6. Como obter seiva e preparar uma cápsula com seiva?
7. Quais habilidades começam disponíveis e onde as demais são aprendidas? O gancho inicial da história já pode ser usado no começo?
8. Como deixar e recolher o chapéu? Ele volta a ser equipado ao renascer? Onde não pode ser colocado?
9. Quais dados são gravados em cada save e em quais momentos? O chapéu também grava a partida ou apenas define o retorno?
10. As regras provisórias de regeneração em sequência, reinício do relógio e preenchimento da vida nova serão mantidas?

### Conteúdo e balanceamento

Ainda faltam os tipos de inimigo e armadilha, a distribuição dos interativos de vida e aprendizado, as métricas de movimento, os tempos e alcances das habilidades e a duração pretendida da campanha. Também precisam ser definidos os limites de pilha, o comportamento da bolsa cheia e as regras para objetos deixados depois de várias mortes.

Para os recursos sazonais, faltam nomes, desenhos e frequência das quatro frutas. Para as flores, faltam características, localização, referências e estado de produção de cada sprite. As vinte espécies já estão selecionadas, mas a ficha individual de cada uma ainda precisa ser preenchida.

### Interface e apresentação

É necessário concluir o conteúdo da pausa, as condições de pausa nas telas de consulta, as teclas finais, a possibilidade de remapeamento e as funções de criar ou apagar saves. Os seis estágios visuais dos vasos precisam de marcos definidos. A espiral de progresso precisa de uma regra de avanço.

Também faltam o diagrama definitivo das telas, as paletas, as referências visuais, a direção sonora e a lista de recursos já produzidos. As opções de acessibilidade, como intensidade dos efeitos de piscar e tremida, ainda podem ser discutidas antes da finalização.

### Produto e distribuição

Precisam ser informados os sistemas operacionais de lançamento, os idiomas, os requisitos mínimos, a duração estimada e o preço. A intenção de compra única deve ser conciliada com a distribuição pelo GitHub, explicando onde ocorre o pagamento e como o jogador recebe a versão completa. Também é necessário definir o que será disponibilizado publicamente: executável, código-fonte, materiais de desenvolvimento ou alguma combinação desses conteúdos.

## Anexo A Modelo de ficha de flor

Nome de exibição: [preencher]

Estação e identificador: [preencher]

Características e referência visual: [preencher]

Localização e requisito para alcançar: [preencher]

Sprite no cenário e variações: [inserir imagens]

Sprite da flor encapsulada: [inserir imagem]

Ícone do inventário e apresentação no catálogo: [inserir imagens]

Descrição exibida ao jogador: [preencher]

Situação da produção: [planejada, em produção, pronta ou revisada]

## Anexo B Paletas e referências

Paleta de Ophelia: [inserir cores e funções]

Paletas de Verão, Outono, Inverno e Primavera: [inserir cores por estação]

Paleta da interface: [inserir cores de fundo, texto, destaque e indisponibilidade]

Cores de dano, cura e aprendizado: [inserir e verificar legibilidade]

Pranchas da personagem, habilidades e cenários: [inserir referências]

Diagrama definitivo de navegação: [inserir após confirmar os retornos e as opções de pausa]
