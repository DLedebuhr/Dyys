extends Camera2D
@export var jogador: Node2D
@export var grupo_jogador: StringName = &"jogador"
@export_group("Olhar para cima / baixo")
@export var acao_olhar_cima: StringName = &"ControleOlharCima"
@export var acao_olhar_baixo: StringName = &"ControleOlharBaixo"
@export_range(0.0, 500.0, 1.0) var deslocamento_olhar_cima: float = 130.0
@export_range(0.0, 500.0, 1.0) var deslocamento_olhar_baixo: float = 105.0
@export_range(0.1, 20.0, 0.1) var suavidade_olhar: float = 5.0
var deslocamento_vertical_atual: float = 0.0

# Preparar o nó
# ---------------------
# Configura referências, sinais e estado inicial.
func _ready() -> void:

	set_process(false)
	call_deferred("_encontrar_jogador")

# Encontrar jogador
# ---------------------
# Procura jogador.
func _encontrar_jogador() -> void:

	if not is_instance_valid(jogador):

		jogador = get_tree().get_first_node_in_group(grupo_jogador) as Node2D

	if not is_instance_valid(jogador):

		push_warning("CameraJogador: arraste a OPHELIA para Jogador no Inspetor ou confirme o grupo '%s'." % grupo_jogador)
		return

	global_position = jogador.global_position
	deslocamento_vertical_atual = 0.0
	make_current()
	reset_smoothing()
	force_update_scroll()
	set_process(true)

# Atualizar a cada quadro
# ---------------------
# Atualiza os temporizadores, a interface ou os efeitos deste nó.
func _process(delta: float) -> void:

	if not is_instance_valid(jogador):

		set_process(false)
		return

	var alvo: float = 0.0
	var pode_olhar: bool = not get_tree().paused
	if jogador is CharacterBody2D:
		var personagem: CharacterBody2D = jogador as CharacterBody2D
		pode_olhar = pode_olhar and personagem.is_on_floor() and absf(personagem.velocity.x) < 12.0
		if personagem.has_method("_reacao_trava"):
			pode_olhar = pode_olhar and not bool(personagem.call("_reacao_trava"))
	if pode_olhar:
		if InputMap.has_action(acao_olhar_cima) and Input.is_action_pressed(acao_olhar_cima):
			alvo = -deslocamento_olhar_cima
		elif InputMap.has_action(acao_olhar_baixo) and Input.is_action_pressed(acao_olhar_baixo):
			alvo = deslocamento_olhar_baixo
	deslocamento_vertical_atual = lerpf(deslocamento_vertical_atual, alvo, 1.0 - exp(-suavidade_olhar * delta))
	global_position = jogador.global_position + Vector2(0.0, deslocamento_vertical_atual)
