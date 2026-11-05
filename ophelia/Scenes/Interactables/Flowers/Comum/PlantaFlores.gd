@tool
extends Node2D

signal flor_coletada(id_item: StringName)

@export_group("Identificação")
@export var id_item: StringName = &""
@export var acao_interagir: StringName = &"ControleInteragir"

@export_group("Coleta e regeneração")
@export_range(10.0, 500.0, 1.0) var distancia_coleta: float = 100.0
@export_range(1.0, 600.0, 1.0) var segundos_regeneracao: float = 10.0
@export_range(0.1, 3.0, 0.05) var duracao_reaparecer: float = 0.65

@export_group("Flor em partículas")
@export_range(0.0, 1.0, 0.01) var tempo_manter_forma: float = 0.16
@export_range(0.2, 3.0, 0.05) var duracao_dispersao: float = 0.9
@export_range(1.0, 200.0, 1.0) var velocidade_dispersao: float = 45.0
@export_range(100, 4000, 100) var limite_particulas: int = 1800

@export_group("Som")
@export var som_coleta: AudioStream
@export var barramento_som: StringName = &"Master"
@export var volume_coleta_db: float = 0.0

const EFEITO: Script = preload("FlorEmParticulas.gd")
var _flores: Array[Node2D] = []
var _animacoes: Array[Tween] = []
var _cores_originais: Array[Color] = []
var _quantidade: int = 0
var _restante: float = 0.0

# Preparar os encaixes da espécie
# ---------------------
# Usa os nós já montados na cena e compartilha a seleção com os outros interativos.
func _ready() -> void:

	var grupo: Node = get_node_or_null("Flores")

	if grupo == null:

		push_warning("PlantaFlores: adicione o nó Flores com os encaixes da espécie.")
		return

	for filho in grupo.get_children():

		if filho is Node2D and filho.get_node_or_null("Ponta") is Sprite2D:

			_flores.append(filho)
			_animacoes.append(null)
			var ponta: Sprite2D = filho.get_node("Ponta")
			_cores_originais.append(ponta.modulate)

	_quantidade = _flores.size()

	if not Engine.is_editor_hint():

		add_to_group("coletaveis_ophelia")

# Atualizar movimento e reposição
# ---------------------
# A espécie cuida do movimento; esta base recupera uma flor por intervalo.
func _process(delta: float) -> void:

	_atualizar_movimento(delta)

	if Engine.is_editor_hint() or _quantidade >= _flores.size():

		return

	_restante -= delta

	while _restante <= 0.0 and _quantidade < _flores.size():

		_recuperar(_quantidade)
		_quantidade += 1
		_restante += maxf(segundos_regeneracao, 0.01)

# Receber o movimento da espécie
# ---------------------
# Cada planta implementa este método para seu caule, suas folhas e seus encaixes.
func _atualizar_movimento(_delta: float) -> void:

	pass

# Verificar a interação
# ---------------------
# Exige flor disponível, proximidade e personagem viva.
func pode_interagir(jogador: CharacterBody2D) -> bool:

	if Engine.is_editor_hint() or _quantidade <= 0 or not is_instance_valid(jogador):

		return false

	if get_tree().paused or not jogador.is_in_group("jogador"):

		return false

	if global_position.distance_to(jogador.global_position) > distancia_coleta:

		return false

	var vida: Node = jogador.get_node_or_null("Vitalidade")
	return vida != null and bool(vida.call("esta_viva"))

# Informar a ação ao indicador
# ---------------------
# A tecla é acrescentada pelo indicador de interação existente.
func obter_mensagem_interacao() -> String:

	return "COLETAR"

# Colher a próxima flor
# ---------------------
# Só altera a planta quando a bolsa aceita o item, preservando as bases e os triângulos.
func interagir(jogador: CharacterBody2D) -> bool:

	if id_item == &"" or not pode_interagir(jogador):

		return false

	var bolsa: Node = jogador.get_node_or_null("Inventario")

	if bolsa == null or not bool(bolsa.call("adicionar", id_item, 1)):

		return false

	_quantidade -= 1
	var indice: int = _quantidade

	if _animacoes[indice] != null and _animacoes[indice].is_valid():

		_animacoes[indice].kill()

	var ponta: Sprite2D = _flores[indice].get_node("Ponta")
	var base: PackedVector2Array = PackedVector2Array()

	if _flores[indice].has_method("obter_base_preservada"):

		base = _flores[indice].call("obter_base_preservada")

	var efeito: Node2D = EFEITO.new() as Node2D
	get_tree().current_scene.add_child(efeito)
	efeito.call("iniciar", ponta, tempo_manter_forma, duracao_dispersao, velocidade_dispersao, limite_particulas, base)
	ponta.hide()
	ponta.modulate = _cores_originais[indice]
	_restante = segundos_regeneracao
	_apos_coleta(indice)
	_tocar_som()
	flor_coletada.emit(id_item)
	return true

# Receber a reação da espécie
# ---------------------
# Permite balançar o galho coletado sem repetir a lógica da coleta.
func _apos_coleta(_indice: int) -> void:

	pass

# Recuperar uma flor no mesmo encaixe
# ---------------------
# Usa a mesma textura e variação, restaurando a opacidade suavemente.
func _recuperar(indice: int) -> void:

	var ponta: Sprite2D = _flores[indice].get_node("Ponta")
	ponta.show()
	ponta.modulate = _cores_originais[indice]
	ponta.modulate.a = 0.0
	var animacao: Tween = create_tween()
	_animacoes[indice] = animacao
	animacao.tween_property(ponta, "modulate:a", _cores_originais[indice].a, duracao_reaparecer).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# Tocar o som configurado
# ---------------------
# Permite coletas consecutivas sem interromper o som anterior.
func _tocar_som() -> void:

	if som_coleta == null:

		return

	var audio: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	audio.stream = som_coleta
	audio.bus = barramento_som
	audio.volume_db = volume_coleta_db
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
