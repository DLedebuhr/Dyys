@tool
extends Node2D

signal capsula_preenchida(jogador: CharacterBody2D)

@export_group("Interação")
@export var acao_interagir: StringName = &"ControleInteragir"
@export_range(10.0, 500.0, 1.0) var distancia_coleta: float = 100.0
@export var acompanhar_bacias: bool = true
@export var mensagem_encher: String = "ENCHER CÁPSULA"
@export var mensagem_sem_capsulas: String = "SEM CÁPSULAS DISPONÍVEIS"

@export_group("Som ao encher")
@export var som_encher: AudioStream
@export var barramento_som: StringName = &"Master"
@export var volume_encher_db: float = 0.0

var _avisou_integracao: bool = false


# Preparar a fonte
# ---------------------
# Mantém a água independente da interação e prepara os pontos das três bacias.
func _ready() -> void:

	_atualizar_pontos()


# Acompanhar os ajustes da água
# ---------------------
# Faz os pontos de interação seguirem as bacias editadas na cena de água.
func _process(_delta: float) -> void:

	_atualizar_pontos()


# Atualizar os pontos de coleta
# ---------------------
# Usa o centro de cada bacia; desative o acompanhamento para posicionar manualmente.
func _atualizar_pontos() -> void:

	if not is_node_ready():

		return

	for i in range(1, 4):

		var ponto: Marker2D = get_node("PontosColeta/Bacia%d" % i) as Marker2D

		if acompanhar_bacias:

			var agua: Node2D = get_node("Agua/Ponto%d/Agua" % i) as Node2D
			var dimensoes: Vector2 = agua.get("tamanho")
			ponto.global_position = agua.to_global(dimensoes * 0.5)

		if not Engine.is_editor_hint():

			ponto.set("acao_interagir", acao_interagir)
			ponto.set("distancia_coleta", distancia_coleta)


# Consultar o inventário da personagem
# ---------------------
# Usa o mesmo nó Inventario empregado pelos demais coletáveis.
func _obter_inventario(jogador: CharacterBody2D) -> Node:

	if not is_instance_valid(jogador):

		return null

	return jogador.get_node_or_null("Inventario")


# Consultar cápsulas vazias
# ---------------------
# Considera apenas as cápsulas guardadas na bolsa, sem retirar ingredientes da oficina.
func possui_capsula(jogador: CharacterBody2D) -> bool:

	var inventario: Node = _obter_inventario(jogador)

	return inventario != null and inventario.has_method("quantidade") and int(inventario.call("quantidade", &"Capsula")) > 0


# Escolher a mensagem da fonte
# ---------------------
# Mantém a indicação visível mesmo quando não existe cápsula para encher.
func obter_mensagem(jogador: CharacterBody2D) -> String:

	return mensagem_encher if possui_capsula(jogador) else mensagem_sem_capsulas


# Encher uma cápsula
# ---------------------
# Solicita uma troca atômica no mesmo espaço da bolsa, sem remover ou adicionar por etapas.
func encher_capsula(jogador: CharacterBody2D) -> bool:

	if Engine.is_editor_hint() or get_tree().paused or not possui_capsula(jogador):

		return false

	var inventario: Node = _obter_inventario(jogador)

	if not inventario.has_method("encher_capsula_com_seiva"):

		if not _avisou_integracao:

			_avisou_integracao = true
			push_warning("Seiva: adicione encher_capsula_com_seiva() ao script atual do inventário.")

		return false

	if not bool(inventario.call("encher_capsula_com_seiva")):

		return false

	_tocar_som(jogador.global_position)
	capsula_preenchida.emit(jogador)

	return true


# Tocar o preenchimento
# ---------------------
# Reproduz o efeito sonoro na posição da personagem que encheu a cápsula.
func _tocar_som(posicao: Vector2) -> void:

	if som_encher == null:

		return

	var audio: AudioStreamPlayer2D = $SomEncher
	audio.global_position = posicao
	audio.stream = som_encher
	audio.bus = barramento_som if AudioServer.get_bus_index(barramento_som) >= 0 else &"Master"
	audio.volume_db = volume_encher_db
	audio.play()
