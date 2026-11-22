extends Node2D
@onready var personagem = $OPHELIA
@onready var alvo = $Alvo
@onready var estado: Label = $Interface/Estado

# Preparar o nó
# ---------------------
# Configura referências, sinais e estado inicial.
func _ready() -> void:

	FundoParticulas.desativar()
	personagem.habilidades.definir_modo_debug(true)
	personagem.imprimir_reacoes = false
	queue_redraw()

# Atualizar a cada quadro
# ---------------------
# Atualiza os temporizadores, a interface ou os efeitos deste nó.
func _process(_delta: float) -> void:

	var defesa: String = "ATIVA" if personagem.lenco.defesa_ativa() else "inativa"
	var pose: String = personagem.EstadoPose.keys()[personagem.estado_pose]
	estado.text = "Vida: %d/%d   |   Escudo: %s   |   Projéteis disponíveis: %d/2\nPose: %s   |   Vida do alvo: %d\nModo debug libera habilidades para este cenário; desbloqueios reais não são alterados." % [personagem.vitalidade.vida_atual, personagem.vitalidade.vida_maxima, defesa, 2 - personagem.lenco.projeteis.size(), pose, alvo.vida]

# Desenhar o efeito
# ---------------------
# Desenha os elementos visuais com o estado atual.
func _draw() -> void:

	draw_rect(Rect2(0, 0, 1920, 1080), Color("171923"))
	draw_line(Vector2(0, 651), Vector2(1920, 651), Color("7caaae"), 3.0)
