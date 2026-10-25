# Decisões aplicadas na nova OPHELIA

| Ponto do guia | Decisão implementada |
|---|---|
| 5.1 — efeitos duplicados | Uma instância explícita em Lenco/Efeitos e uma camada Visual/EfeitosTras já montada na cena. |
| 5.2 — projétil fixo | O nó genérico foi retirado. O lançador instancia uma PackedScene própria por disparo. |
| 5.3 — mecanismo de defesa | Vitalidade verifica o escudo antes de aceitar dano; a área do escudo intercepta projéteis hostis. Há exemplo e teste. |
| 5.4 — movimento | Coordenador calcula movimento, impulso e restrição prevista da corda antes de um único move_and_slide no modo normal. |
| 5.5 — InputMap | Todas as teclas estão no arquivo de configuração do InputMap. Nenhum componente cria/remapeia ações durante o jogo. |
| 5.7 — nomes | Nova cena OPHELIA, SpritePersonagem, ColisaoCorpo, SensorTeto, SensorGancho, SensorInteracao, Lenco e OrigemLenco. Referências por nomes únicos. |
| 5.8 — efeitos padronizados | Material aditivo, texturas de brilho e curva de partículas compartilhados em EfeitosComuns. Shader das asas separado. |
| 5.9 — aperto da tecla | Eventos discretos são guardados em fila e executados após a transição, inclusive se a tecla já foi solta. Pulo não fica preso atrás de recarga do lenço. |

O catálogo continua integrado por uma interface explícita: definir_catalogo_completo. Não foi inventado um catálogo nem um sistema de save. A personagem mantém seus métodos de integração e o grupo jogador.

## Escolha de arquitetura

Ophelia.gd e ControladorLenco.gd são coordenadores e donos do estado/configuração compartilhados. Os componentes RefCounted recebem uma referência a esse coordenador e implementam os algoritmos de sua responsabilidade. Isso mantém uma única fonte de estado sem transformar cada função em um nó.

O antigo controlador do Player tinha cerca de 810 linhas; o novo coordenador possui aproximadamente 350, com movimento, reação, animação e interação separados. O controlador completo do lenço tinha cerca de 1.417 linhas; a nova coordenação tem aproximadamente 500, com visual, combate e gancho separados. A configuração continua acessível no Inspector dos coordenadores.

O Player e seus scripts antigos permanecem independentes. Os scripts com class_name usam o prefixo Ophelia para coexistir com as classes antigas.
