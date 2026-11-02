extends CanvasLayer

@export_group("Mensagens por tipo")
@export var mensagem_fruta: String = "COLETAR"
@export var mensagem_vida: String = "COLETAR"
@export var mensagem_habilidade: String = "APRENDER"
@export var intervalo_consulta: float = 0.1

@onready var texto: Label = $Margem/Texto

var _jogador: CharacterBody2D
var _alvo: Node2D
var _espera: float = 0.0

# Preparar o indicador
# ---------------------
# Mantém a mensagem independente da câmera e oculta ao iniciar.
func _ready() -> void:

	texto.hide()

# Consultar os interativos próximos
# ---------------------
# Centraliza a busca em dez consultas por segundo, em vez de uma busca por fruta.
func _process(delta: float) -> void:

	if get_tree().paused:

		texto.hide()
		return

	_espera -= delta

	if _espera > 0.0:

		return

	_espera = maxf(intervalo_consulta, 0.02)
	_atualizar_alvo()

# Escolher a mensagem disponível
# ---------------------
# Usa o mesmo alvo para o texto e para o próximo comando de interação.
func _atualizar_alvo() -> void:

	if not is_instance_valid(_jogador):

		_jogador = get_tree().get_first_node_in_group("jogador") as CharacterBody2D

	_alvo = InteracaoProxima.escolher(_jogador)
	texto.visible = is_instance_valid(_alvo) and not get_tree().paused

	if not texto.visible:

		return

	var mensagem: String = mensagem_fruta

	if _alvo.has_signal("vida_maxima_aumentada"):

		mensagem = mensagem_vida

	elif _alvo.has_signal("habilidade_habilitada"):

		mensagem = mensagem_habilidade

	if _alvo.has_method("obter_mensagem_interacao"):

		mensagem = str(_alvo.call("obter_mensagem_interacao"))

	var acao: StringName = StringName(_alvo.get("acao_interagir"))
	texto.text = "%s [ %s ]" % [mensagem, _nome_tecla(acao)]

# Identificar a tecla configurada
# ---------------------
# Lê o Mapa de Entrada sem criar nem alterar ações.
func _nome_tecla(acao: StringName) -> String:

	if not InputMap.has_action(acao):

		return "SEM TECLA"

	for evento in InputMap.action_get_events(acao):

		if evento is InputEventKey:

			var tecla: int = evento.physical_keycode if evento.physical_keycode != 0 else evento.keycode
			return OS.get_keycode_string(tecla)

		if evento is InputEventMouseButton:

			return "MOUSE %d" % evento.button_index

		if evento is InputEventJoypadButton:

			return evento.as_text()

	return "SEM TECLA"

# Acionar somente o objeto indicado
# ---------------------
# Ignora repetição e revalida alcance e disponibilidade antes de interagir.
func _unhandled_input(event: InputEvent) -> void:

	if get_tree().paused or not is_instance_valid(_alvo) or not is_instance_valid(_jogador):

		return

	if event is InputEventKey and event.echo:

		return

	var acao: StringName = StringName(_alvo.get("acao_interagir"))

	if not InputMap.has_action(acao) or not event.is_action_pressed(acao):

		return

	if bool(_alvo.call("pode_interagir", _jogador)) and bool(_alvo.call("interagir", _jogador)):

		get_viewport().set_input_as_handled()

	_atualizar_alvo()
