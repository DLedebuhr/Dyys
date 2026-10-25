extends Node2D
@onready var personagem = $OPHELIA
@onready var alvo = $Alvo
@onready var estado: Label = $Interface/Estado
func _ready() -> void:
	personagem.habilidades.definir_modo_debug(true)
	personagem.imprimir_reacoes = false
	queue_redraw()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("ControleTesteHostil"):
		var hostil = preload("res://ophelia/testes/ProjetilHostilTeste.gd").new()
		hostil.position = personagem.global_position + Vector2(300, 25)
		add_child(hostil)
	elif event.is_action_pressed("ControleTesteRestaurar"):
		personagem.vitalidade.restaurar()
		alvo.vida = 100
func _process(_delta: float) -> void:
	var defesa: String = "ATIVA" if personagem.lenco.defesa_ativa() else "inativa"
	var pose: String = personagem.EstadoPose.keys()[personagem.estado_pose]
	estado.text = "Vida: %d/%d   |   Escudo: %s   |   Projéteis disponíveis: %d/2\nPose: %s   |   Vida do alvo: %d\nModo debug libera habilidades para este cenário; desbloqueios reais não são alterados." % [personagem.vitalidade.vida_atual, personagem.vitalidade.vida_maxima, defesa, 2 - personagem.lenco.projeteis.size(), pose, alvo.vida]
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color("171923"))
	draw_line(Vector2(0, 651), Vector2(1920, 651), Color("7caaae"), 3.0)
