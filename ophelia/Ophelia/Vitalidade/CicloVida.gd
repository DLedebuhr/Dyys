extends Node
## Congela a personagem, conserva a fase e devolve ao ponto inicial após morrer.
@export var vitalidade: Node
@export var visuais: Array[CanvasItem] = [] # Sprite, Lenço, Asas, Sombra. Não incluir EfeitosVida.
@export var ponto_renascimento: Marker2D # Opcional; vazio = posição inicial da personagem.
@export_range(0.3, 5.0, 0.1) var espera_renascimento: float = 1.4
var _corpo: CharacterBody2D
var _inicio: Vector2
var _restante: float = -1.0
var _modo_anterior: ProcessMode
var _visibilidade: Array[bool] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_corpo = get_parent() as CharacterBody2D
	if vitalidade == null:
		vitalidade = get_parent().get_node_or_null("Vitalidade")
	if _corpo == null or vitalidade == null:
		push_error("CicloVida deve ser filho da OPHELIA e receber Vitalidade.")
		return
	_inicio = _corpo.global_position
	vitalidade.morreu.connect(_ao_morrer)

func _ao_morrer() -> void:
	if _restante >= 0.0:
		return
	_restante = espera_renascimento
	_modo_anterior = _corpo.process_mode
	_corpo.velocity = Vector2.ZERO
	_limpar_estado()
	_corpo.process_mode = Node.PROCESS_MODE_DISABLED
	_visibilidade.clear()
	for visual in visuais:
		_visibilidade.append(visual.visible if is_instance_valid(visual) else false)
		if is_instance_valid(visual):
			visual.hide()

func _process(delta: float) -> void:
	if _restante < 0.0:
		return
	_restante -= delta
	if _restante <= 0.0:
		_renascer()

func _renascer() -> void:
	_restante = -1.0
	_corpo.global_position = ponto_renascimento.global_position if is_instance_valid(ponto_renascimento) else _inicio
	_corpo.velocity = Vector2.ZERO
	_limpar_estado()
	vitalidade.call("restaurar")
	for i in range(visuais.size()):
		if is_instance_valid(visuais[i]):
			visuais[i].visible = _visibilidade[i]
	_corpo.process_mode = _modo_anterior
	call_deferred("_reposicionar_camera")

func _limpar_estado() -> void:
	if _corpo.has_method("limpar_comandos"):
		_corpo.call("limpar_comandos")
	var lenco: Node = _corpo.get_node_or_null("Lenco")
	if lenco != null and lenco.has_method("soltar_tudo"):
		lenco.call("soltar_tudo")
	# Só redefine propriedades existentes, sem exigir uma versão antiga de Ophelia.gd.
	var valores: Dictionary = {"esta_sentada": false, "sentou_por_inatividade": false, "esta_levantando": false, "planando": false, "tempo_coyote": 0.0, "tempo_jump_buffer": 0.0, "tempo_embalo": 0.0, "tempo_ocioso": 0.0, "tempo_frontal_imovel": 0.0, "estado_pose": 0, "reacao_atual": &"", "reacao_pendente": &"", "pulo_apos_transicao": false, "tempo_transicao_pose": 0.0}
	for propriedade in _corpo.get_property_list():
		var nome: String = propriedade["name"]
		if valores.has(nome):
			_corpo.set(nome, valores[nome])

func _reposicionar_camera() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		camera.global_position = _corpo.global_position
		camera.reset_smoothing()
		camera.force_update_scroll()
