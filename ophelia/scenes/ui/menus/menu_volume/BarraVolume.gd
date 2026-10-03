extends Control

# Nome do barramento de áudio na Godot ("Master", "Music" ou "SFX")
@export var bus_name: String = "Master"

# Nós da UI dentro do ShaderBarra
@onready var barra_fundo: TextureRect = $BarraFundo
@onready var ponteiro: TextureRect = $Ponteiro

# Configurações de passo relativas (5 pontos: 0 a 4 com 50px de espaçamento)
const PASSO_DISTANCIA: float = 50.0 
const PASSO_INICIAL: int = 2        # Ponto central do meio (Passo 2 / 50%)
const TOTAL_PASSOS: int = 4         # Total de passos (0, 1, 2, 3, 4)

var x_base_ponteiro: float = 0.0     # Posição X base do ponteiro na cena
var passo_atual: int = 2            # Inicia no ponto do meio
var tween_ponteiro: Tween
var bus_index: int = -1

func _ready() -> void:
	# Permite receber foco do teclado/controle diretamente
	focus_mode = FOCUS_ALL
	
	bus_index = AudioServer.get_bus_index(bus_name)
	
	if ponteiro:
		# Guarda a posição X exata do ponteiro definida no editor (Passo 2)
		x_base_ponteiro = ponteiro.position.x
		ponteiro.pivot_offset = ponteiro.size / 2.0

	_sincronizar_volume_com_audio()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			_atualizar_por_clique_mouse(mb.position.x)

func _unhandled_input(event: InputEvent) -> void:
	if not has_focus():
		return

	if event.is_action_pressed("ui_left"):
		alterar_passo(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		alterar_passo(1)
		get_viewport().set_input_as_handled()

func alterar_passo(delta: int) -> void:
	passo_atual = clampi(passo_atual + delta, 0, TOTAL_PASSOS)
	_aplicar_volume_e_animar()

func _calcular_posicao_x(passo: int) -> float:
	var diferenca_passos: float = float(passo - PASSO_INICIAL)
	return x_base_ponteiro + (diferenca_passos * PASSO_DISTANCIA)

func _atualizar_por_clique_mouse(mouse_x: float) -> void:
	var x_ponto_zero: float = _calcular_posicao_x(0)
	var distancia_relativa: float = mouse_x - x_ponto_zero
	
	passo_atual = roundi(distancia_relativa / PASSO_DISTANCIA)
	passo_atual = clampi(passo_atual, 0, TOTAL_PASSOS)
	
	_aplicar_volume_e_animar()

func _aplicar_volume_e_animar() -> void:
	# 1. Ajuste do volume do áudio no AudioServer
	var porcentagem: float = float(passo_atual) / float(TOTAL_PASSOS)
	var db_value: float = linear_to_db(porcentagem)
	
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, db_value)
		AudioServer.set_bus_mute(bus_index, passo_atual == 0)

	# 2. Animação de deslizamento e pop no ponteiro
	if ponteiro:
		var destino_x: float = _calcular_posicao_x(passo_atual)

		if tween_ponteiro and tween_ponteiro.is_running():
			tween_ponteiro.kill()

		tween_ponteiro = create_tween().set_parallel(true)

		tween_ponteiro.tween_property(ponteiro, "position:x", destino_x, 0.15)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

		ponteiro.scale = Vector2(1.2, 1.2)
		tween_ponteiro.tween_property(ponteiro, "scale", Vector2(1.0, 1.0), 0.12)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)

func _sincronizar_volume_com_audio() -> void:
	if bus_index != -1:
		var db_atual: float = AudioServer.get_bus_volume_db(bus_index)
		var linear_val: float = db_to_linear(db_atual)
		passo_atual = roundi(linear_val * float(TOTAL_PASSOS))

	if ponteiro:
		ponteiro.position.x = _calcular_posicao_x(passo_atual)
