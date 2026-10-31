# Partículas de Ophelia

## Instalar manualmente

1. Pare o teste do jogo.
2. Na pasta Ophelia que já existe no seu projeto, substitua somente os arquivos listados abaixo, mantendo cada um na mesma subpasta. Não coloque uma pasta Ophelia dentro de outra.
3. Adicione EstiloParticulas.gd e EstiloParticulas.tres à pasta Ophelia/Efeitos.
4. Aguarde o Godot importar os scripts. Abra OPHELIA.tscn e teste dano, morte, fruta, planar, ataque e a batida de pé da reação irritada.

Não é necessário criar nós nem substituir OPHELIA.tscn. A montagem da cena enviada foi mantida. CicloVida encontra automaticamente as duas fitas e o controlador do lenço.

## Arquivos substituídos

- Componentes/InteracoesOphelia.gd
- Efeitos/Asas.gd
- Efeitos/EfeitosComuns.gd
- Efeitos/EfeitosLenco.gd
- Ferramentas/VooDebug.gd
- Lenco/ControladorLenco.gd
- Lenco/VisualLenco.gd
- Projeteis/ProjetilLenco.gd
- Vitalidade/CicloVida.gd
- Vitalidade/EfeitosVida.gd

## Onde mudar a textura e a cor

No painel Arquivos do Godot, abra Ophelia/Efeitos/EstiloParticulas.tres.

- Textura: arraste uma imagem branca com fundo transparente. Deixe vazio para usar o cintilo criado por código.
- Cor: muda a cor compartilhada das partículas da personagem. O padrão é branco levemente azulado.

Edite esse recurso original compartilhado. Não precisa configurar cada ataque separadamente. As cores antigas específicas das partículas deixam de ser usadas pelos emissores ajustados. As cores do tecido, dos rastros e da redoma continuam independentes.

O estilo se aplica aos cintilos das asas, às faíscas de ataque/defesa/propulsor, aos projéteis, à batida de pé, aos efeitos de vida e ao voo de debug. A HUD e os interativos do cenário não estão no ZIP enviado e não foram alterados.

## Dano, morte e cura

O tremor é aplicado somente ao desenho: sprite, asas, fitas e pontas acompanham o mesmo deslocamento. A colisão, o gancho e o alcance do ataque não tremem.

A morte distribui cintilos sobre os pixels visíveis do quadro atual e ao longo das duas fitas. O centro considera a imagem da personagem, sua escala e posição, e não a gola do lenço. As fitas e o controlador são ocultados junto com o corpo e reaparecem no renascimento. Os efeitos de morte continuam processando enquanto a personagem está desativada.

Em Visual/EfeitosVida, Centro Efeitos é uma correção opcional sobre o posicionamento automático; deixe em (0, 0) inicialmente. Quantidade Particulas Morte e Forca Tremida ajustam a intensidade.

Somente consumir fruta emite partículas de cura; a regeneração natural não emite partículas na personagem.

## Validação e limite

Os scripts alterados foram carregados no Godot 4.5.1. Em uma cena de teste, foram verificados tremor, cura natural sem emissão, fruta com emissão, ocultação das fitas e do corpo, processamento dos efeitos durante a morte e renascimento.

O projeto usa Godot 4.7.1. As imagens externas referenciadas por OPHELIA.tscn não vieram neste ZIP, então não foi possível validar a aparência final na cena completa com sua arte.
