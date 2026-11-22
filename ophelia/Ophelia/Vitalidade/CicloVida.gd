extends Node
const ITEM_PERDIDO = preload("res://Ophelia/Inventario/ItemPerdido.gd")
const FLORES_QUEBRADAS = preload("res://Ophelia/Inventario/FloresQuebradas.gd")
## Congela a personagem, conserva a fase e devolve ao ponto inicial após morrer.
@export var vitalidade: Node
@export var visuais: Array[CanvasItem] = [] # Sprite, Lenço, Asas, Sombra. Não incluir EfeitosVida.
@export var ponto_renascimento: Marker2D # Opcional; vazio = posição inicial da personagem.
@export_range(0.3, 5.0, 0.1) var espera_renascimento: float = 1.4
@export_group("Itens perdidos na morte")
@export_range(1.0, 3600.0, 1.0) var prazo_recuperar_itens: float = 300.0 # GDD: 5 minutos
@export_range(0.1, 600.0, 0.1) var prazo_recuperar_itens_debug: float = 30.0
@export var grupo_pontos_seguros: StringName = &"PontoSeguroItens"
@export_range(50.0, 2400.0, 10.0) var distancia_maxima_ponto_seguro: float = 1200.0
@export_range(20.0, 150.0, 1.0) var distancia_recolher_itens: float = 56.0
var _corpo: CharacterBody2D
var _inicio: Vector2
var _restante: float = -1.0
var _modo_anterior: ProcessMode
var _visibilidade: Array[bool] = []

# Preparar o nó
# ---------------------
# Configura referências, sinais e estado inicial.
func _ready() -> void:

	process_mode = Node.PROCESS_MODE_PAUSABLE
	_corpo = get_parent() as CharacterBody2D

	if vitalidade == null:

		vitalidade = get_parent().get_node_or_null("Vitalidade")

	if _corpo == null or vitalidade == null:

		push_error("CicloVida deve ser filho da OPHELIA e receber Vitalidade.")
		return

	for caminho in ["Visual/SpritePersonagem", "Visual/Asas", "Visual/Sombra", "Visual/FitaTras", "Visual/FitaFrente", "Visual/EfeitosTras", "Lenco"]:

		var visual: CanvasItem = _corpo.get_node_or_null(caminho) as CanvasItem

		if visual != null and not visuais.has(visual):

			visuais.append(visual)

	_inicio = _corpo.global_position
	vitalidade.morreu.connect(_ao_morrer)

# Ocultar a personagem ao morrer
# ---------------------
# Interrompe a personagem e oculta seus visuais até o renascimento.
func _ao_morrer() -> void:

	if _restante >= 0.0:

		return

	_restante = espera_renascimento
	_soltar_inventario()
	_modo_anterior = _corpo.process_mode
	_corpo.velocity = Vector2.ZERO
	_corpo.process_mode = Node.PROCESS_MODE_DISABLED
	_visibilidade.clear()

	for visual in visuais:

		_visibilidade.append(visual.visible if is_instance_valid(visual) else false)

		if is_instance_valid(visual):

			visual.hide()

	_limpar_estado()

# Atualizar a cada quadro
# ---------------------
# Atualiza os temporizadores, a interface ou os efeitos deste nó.
func _process(delta: float) -> void:

	if _restante < 0.0:

		return

	_restante -= delta

	if _restante <= 0.0:

		_renascer()

# Renascer
# ---------------------
# Processa renascer.
func _renascer() -> void:

	_restante = -1.0
	var destino: Vector2 = ponto_renascimento.global_position if is_instance_valid(ponto_renascimento) else _inicio
	var checkpoint: Node = _corpo.get_node_or_null("CheckpointChapeu")
	if checkpoint != null and checkpoint.has_method("consumir_checkpoint"):
		destino = checkpoint.call("consumir_checkpoint", destino)
	_corpo.global_position = destino
	_corpo.velocity = Vector2.ZERO
	_limpar_estado()
	vitalidade.call("restaurar")

	for i in range(visuais.size()):

		if is_instance_valid(visuais[i]):

			visuais[i].visible = _visibilidade[i]

	_corpo.process_mode = _modo_anterior
	if checkpoint != null and checkpoint.has_method("restaurar_chapeu"):
		checkpoint.call("restaurar_chapeu")
	call_deferred("_reposicionar_camera")
	call_deferred("_salvar_renascimento")

# Limpar estado
# ---------------------
# Limpa estado.
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

# Reposicionar camera
# ---------------------
# Reposiciona camera.
func _reposicionar_camera() -> void:

	var camera: Camera2D = get_viewport().get_camera_2d()

	if camera != null:

		camera.global_position = _corpo.global_position
		camera.reset_smoothing()
		camera.force_update_scroll()

# Soltar tudo que não é flor comum; a bolsa faz a separação e mantém as encapsuladas.
func _soltar_inventario() -> void:
	var bolsa: Node = _corpo.get_node_or_null("Inventario")
	if bolsa == null or not bolsa.has_method("retirar_na_morte"):
		return
	var total_flores: int = int(bolsa.call("contar_flores_comuns")) if bolsa.has_method("contar_flores_comuns") else 0
	var itens: Array = bolsa.call("retirar_na_morte")
	var mundo: Node = get_tree().current_scene
	if mundo == null:
		mundo = get_tree().root
	if total_flores > 0:
		var petalas: Node2D = FLORES_QUEBRADAS.new()
		petalas.call("configurar", total_flores)
		mundo.add_child(petalas)
		petalas.global_position = _corpo.global_position
	var posicao_segura: Vector2 = _encontrar_ponto_seguro()
	var tempo_itens: float = prazo_recuperar_itens_debug if _corpo.has_method("em_modo_debug") and _corpo.em_modo_debug() else prazo_recuperar_itens
	for i in range(itens.size()):
		var dados: Dictionary = itens[i]
		if int(dados.get("quantidade", 0)) <= 0:
			continue
		var perdido: Node2D = ITEM_PERDIDO.new()
		perdido.call("configurar", dados, _corpo, bolsa, tempo_itens, distancia_recolher_itens)
		mundo.add_child(perdido)
		# Concentra itens em uma pequena área acima do ponto seguro; não
		# espalhar horizontalmente para fora de plataformas estreitas.
		var x: float = float((i % 3) - 1) * 10.0
		var y: float = float(floori(float(i) / 3.0)) * 9.0
		perdido.global_position = posicao_segura + Vector2(x, -y)


func _salvar_renascimento() -> void:
	var persistencia := _corpo.get_node_or_null("PersistenciaOphelia")
	if persistencia != null and persistencia.has_method("salvar_agora"):
		persistencia.call("salvar_agora")

# Marcadores Marker2D no grupo PontoSeguroItens são colocados pelo level designer
# em plataformas acessíveis. Sem marcador, usa o local inicial válido do nível.
func _encontrar_ponto_seguro() -> Vector2:
	var origem: Vector2 = _corpo.global_position
	var candidato: Vector2 = _inicio
	var menor: float = INF
	for no in get_tree().get_nodes_in_group(grupo_pontos_seguros):
		if not (no is Node2D):
			continue
		var p: Vector2 = no.global_position
		var distancia: float = origem.distance_to(p)
		if distancia < menor and distancia <= distancia_maxima_ponto_seguro:
			menor = distancia
			candidato = p
	return candidato
