extends Camera2D
@export var jogador: Node2D
@export var grupo_jogador: StringName = &"jogador"

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
	make_current()
	reset_smoothing()
	force_update_scroll()
	set_process(true)

# Atualizar a cada quadro
# ---------------------
# Atualiza os temporizadores, a interface ou os efeitos deste nó.
func _process(_delta: float) -> void:

	if not is_instance_valid(jogador):

		set_process(false)
		return

	global_position = jogador.global_position
