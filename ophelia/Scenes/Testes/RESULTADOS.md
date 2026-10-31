# Validação de OPHELIA

Motor: Godot 4.5.1 oficial, headless, física a 60 passos por segundo.

**50 verificações passaram; zero falhas e nenhum erro de script na execução final.**

Os recursos de imagem da conversa não estavam disponíveis. A validação da lógica usou imagens temporárias nos caminhos das artes; essas imagens não fazem parte do pacote. A revisão visual deve ser feita com suas artes no Godot do projeto.

| Nº | Verificação aprovada |
|---:|---|
| 1 | Interface de dano aceita alvo antigo sem retorno |
| 2 | Cena carrega e personagem pousa no chão |
| 3 | Defesa usa a referência explícita da colisão renomeada |
| 4 | Cena não cria ações no InputMap |
| 5 | Uma instância explícita de efeitos |
| 6 | Sem projétil visível/ativo ao iniciar |
| 7 | Direita acelera a personagem |
| 8 | Soltar direção aplica frenagem |
| 9 | Pulo usa evento de aperto |
| 10 | Entrada frontal espelha para a esquerda |
| 11 | Reação termina em EsperarMovimento |
| 12 | Ataque apertado e solto na espera executa após a transição |
| 13 | Saída volta à pose normal |
| 14 | Receber dano fora da defesa reduz vida |
| 15 | Quantidade de dano recebida é exata |
| 16 | Escudo entra em sua janela ativa |
| 17 | Escudo bloqueia receber_dano |
| 18 | Defesa preserva a vida |
| 19 | Área do escudo intercepta projétil hostil |
| 20 | Defesa termina ao esgotar a duração |
| 21 | Dano volta a funcionar depois da defesa |
| 22 | Máximo de dois projéteis ativos |
| 23 | Projéteis permanecem parados antes da recarga |
| 24 | Projéteis retornam e recuperam as cargas após cinco segundos |
| 25 | Projétil parado disponibiliza apoio |
| 26 | Gancho prende no projétil parado |
| 27 | Retorno do projétil solta o gancho |
| 28 | Contato com a personagem antecipa a recuperação |
| 29 | Ataque normal aplica dez de dano uma única vez |
| 30 | Projétil aplica cinco de dano uma única vez |
| 31 | Propulsor impulsiona no sentido contrário ao mouse |
| 32 | Golpe do lenço aponta para o mouse |
| 33 | Propulsor consome um uso aéreo |
| 34 | Pouso restaura o propulsor |
| 35 | S no chão senta e não aciona o propulsor |
| 36 | Novo aperto levanta a personagem |
| 37 | Novo aperto de W no ar inicia planagem |
| 38 | Asas acompanham o início da planagem |
| 39 | Soltar W encerra a planagem no modo segurar |
| 40 | Troca de chapéu preserva reação e espera frontal |
| 41 | Saída frontal espelha para o lado escolhido |
| 42 | Movimento começa depois da transição de saída |
| 43 | Ataque aguardando recarga não bloqueia um pulo |
| 44 | Voo debug pausa o coordenador normal |
| 45 | Voo debug não acumula comandos de combate enquanto a personagem está oculta |
| 46 | Retorno do voo restaura a personagem e o lenço |
| 47 | Lenço volta ao processamento após o voo |
| 48 | Entradas normais são restauradas ao encerrar o voo |
| 49 | Restrição do gancho mantém o corpo dentro do comprimento da corda |
| 50 | Gancho permite balanço contínuo, sem travar o movimento |

Também foi validado o carregamento de CenarioTeste.tscn. O instalador do InputMap foi conferido em arquivo temporário: cria backup, preserva configurações e ações externas e pode ser reaplicado sem duplicar as ações da personagem.
