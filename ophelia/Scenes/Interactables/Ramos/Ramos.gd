@tool
extends Node2D

signal ramo_coletado(id_item: StringName)

@export_group("Identificação")
@export_enum("Verão", "Outono", "Inverno", "Primavera") var estacao: int = 0:

	set(valor):

		estacao = valor
		_solicitar_configuracao()

@export_enum("Duas folhas:2", "Quatro folhas:4") var quantidade_folhas: int = 4:

	set(valor):

		quantidade_folhas = valor
		_solicitar_configuracao()

@export var id_item: StringName = &"Ramo"
@export var acao_interagir: StringName = &"ControleInteragir"

@export_group("Aparência por estação")
@export var visual_verao: VisualRamosOphelia:

	set(valor):

		visual_verao = valor
		_solicitar_configuracao()

@export var visual_outono: VisualRamosOphelia:

	set(valor):

		visual_outono = valor
		_solicitar_configuracao()

@export var visual_inverno: VisualRamosOphelia:

	set(valor):

		visual_inverno = valor
		_solicitar_configuracao()

@export var visual_primavera: VisualRamosOphelia:

	set(valor):

		visual_primavera = valor
		_solicitar_configuracao()

@export_group("Coleta e regeneração")
@export_range(10.0, 500.0, 1.0) var distancia_coleta: float = 100.0
@export_range(1.0, 600.0, 1.0) var segundos_regeneracao: float = 10.0
@export_range(0.1, 3.0, 0.05) var duracao_reaparecer: float = 0.65

@export_group("Ramo em partículas")
@export_range(0.0, 1.0, 0.01) var tempo_manter_forma: float = 0.16
@export_range(0.2, 3.0, 0.05) var duracao_dispersao: float = 0.9
@export_range(1.0, 200.0, 1.0) var velocidade_dispersao: float = 45.0
@export_range(100, 4000, 100) var limite_particulas: int = 1800

@export_group("Movimento")
@export var vento_ativo: bool = true
@export var mostrar_vento_no_editor: bool = false
@export_range(0.0, 30.0, 0.5) var amplitude_vento: float = 4.0
@export_range(0.1, 5.0, 0.1) var velocidade_vento: float = 1.2
@export_range(0.0, 30.0, 0.5) var reacao_coleta: float = 3.0

@export_group("Som")
@export var som_coleta: AudioStream
@export var barramento_som: StringName = &"Master"
@export var volume_coleta_db: float = 0.0

const EFEITO: Script = preload("RamoEmParticulas.gd")
const VISUAL_PADRAO: VisualRamosOphelia = preload("VisualRamosPadrao.tres")

var _galhos: Array[Line2D] = []
var _originais: Array[PackedVector2Array] = []
var _folhas: Array[Node2D] = []
var _imagens: Array[Sprite2D] = []
var _animacoes: Array[Tween] = []
var _reacoes: PackedFloat32Array = PackedFloat32Array()
var _ativos: PackedInt32Array = PackedInt32Array()
var _quantidade: int = 0
var _restante: float = 0.0
var _tempo: float = 0.0
var _configuracao_pendente: bool = false


# Preparar os ramos
# ---------------------
# Guarda os encaixes e integra a planta ao indicador de interação existente.
func _ready() -> void:

	for i in range(4):

		var galho: Line2D = get_node("Galhos/Galho%d" % (i + 1)) as Line2D
		var folha: Node2D = get_node("Folhas/Ramo%d" % (i + 1)) as Node2D

		_galhos.append(galho)
		_originais.append(galho.points.duplicate())
		_folhas.append(folha)
		_imagens.append(folha.get_node("Imagem") as Sprite2D)
		_animacoes.append(null)
		_reacoes.append(100.0)

	_aplicar_configuracao()

	if not Engine.is_editor_hint():

		add_to_group("coletaveis_ophelia")
		add_to_group("PersistenteSave")


# Atualizar a configuração no editor
# ---------------------
# Agrupa alterações do Inspetor antes de preparar os nós novamente.
func _solicitar_configuracao() -> void:

	if not is_node_ready() or _configuracao_pendente:

		return

	_configuracao_pendente = true
	_aplicar_configuracao.call_deferred()


# Escolher a aparência da estação
# ---------------------
# Usa as texturas padrão quando uma estação ainda não foi configurada.
func _obter_visual() -> VisualRamosOphelia:

	var visual: VisualRamosOphelia = null

	match estacao:

		0:

			visual = visual_verao

		1:

			visual = visual_outono

		2:

			visual = visual_inverno

		3:

			visual = visual_primavera

	return visual if visual != null else VISUAL_PADRAO


# Aplicar o modelo e suas texturas
# ---------------------
# A versão de duas folhas utiliza os dois encaixes da direita da referência.
func _aplicar_configuracao() -> void:

	_configuracao_pendente = false

	if _galhos.size() != 4:

		return

	_ativos = PackedInt32Array([0, 2]) if quantidade_folhas == 2 else PackedInt32Array([0, 1, 2, 3])
	var visual: VisualRamosOphelia = _obter_visual()

	for configuracao in [visual_verao, visual_outono, visual_inverno, visual_primavera]:

		if configuracao != null and not configuracao.changed.is_connected(_solicitar_configuracao):

			configuracao.changed.connect(_solicitar_configuracao)

	for i in range(4):

		if _animacoes[i] != null and _animacoes[i].is_valid():

			_animacoes[i].kill()

		_animacoes[i] = null
		_galhos[i].visible = _ativos.has(i)
		_galhos[i].points = _originais[i].duplicate()
		_folhas[i].visible = _ativos.has(i)
		_folhas[i].position = _originais[i][0]
		_folhas[i].rotation = 0.0
		_imagens[i].show()
		_imagens[i].modulate = Color.WHITE
		_imagens[i].self_modulate = visual.cor
		var textura: Texture2D = visual.obter_textura(i)
		_imagens[i].texture = textura if textura != null else VISUAL_PADRAO.obter_textura(i)

	_quantidade = _ativos.size()
	_restante = 0.0


# Atualizar movimento e regeneração
# ---------------------
# Recupera uma folha por intervalo e preserva a ordem inversa da coleta.
func _process(delta: float) -> void:

	if _galhos.size() != 4:

		return

	if not Engine.is_editor_hint() or mostrar_vento_no_editor:

		_atualizar_movimento(delta)

	if Engine.is_editor_hint() or _quantidade >= _ativos.size():

		return

	_restante -= delta

	while _restante <= 0.0 and _quantidade < _ativos.size():

		_recuperar(_ativos[_quantidade])
		_quantidade += 1
		_restante += maxf(segundos_regeneracao, 0.01)


# Animar os encaixes
# ---------------------
# Mantém o pé fixo e faz cada folha acompanhar o balanço de seu galho.
func _atualizar_movimento(delta: float) -> void:

	_tempo += delta

	for indice in _ativos:

		_reacoes[indice] += delta
		var pontos: PackedVector2Array = _originais[indice].duplicate()
		var reacao: float = sin(_reacoes[indice] * 18.0) * exp(-_reacoes[indice] * 4.0) * reacao_coleta

		for j in range(pontos.size()):

			var peso: float = pow(float(j) / maxf(float(pontos.size() - 1), 1.0), 1.7)
			var vento: float = sin(_tempo * velocidade_vento + float(indice) * 0.3 + peso * 0.5) * amplitude_vento if vento_ativo else 0.0
			pontos[j].x += (vento + reacao) * peso

		_galhos[indice].points = pontos
		_folhas[indice].position = pontos[0]
		var direcao_original: Vector2 = _originais[indice][-1] - _originais[indice][0]
		var direcao_atual: Vector2 = pontos[-1] - pontos[0]
		_folhas[indice].rotation = direcao_original.angle_to(direcao_atual)


# Verificar a interação
# ---------------------
# Exige personagem viva, proximidade e pelo menos um ramo disponível.
func pode_interagir(jogador: CharacterBody2D) -> bool:

	if Engine.is_editor_hint() or _quantidade <= 0 or not is_instance_valid(jogador):

		return false

	if get_tree().paused or not jogador.is_in_group("jogador"):

		return false

	if global_position.distance_to(jogador.global_position) > distancia_coleta:

		return false

	var vida: Node = jogador.get_node_or_null("Vitalidade")

	return vida != null and vida.has_method("esta_viva") and bool(vida.call("esta_viva"))


# Informar a mensagem de interação
# ---------------------
# O indicador compartilhado acrescenta a tecla F à mensagem.
func obter_mensagem_interacao() -> String:

	return "COLETAR"


# Coletar um ramo
# ---------------------
# Só remove a folha depois que o inventário aceita uma unidade do item Ramo.
func interagir(jogador: CharacterBody2D) -> bool:

	if id_item == &"" or not pode_interagir(jogador):

		return false

	var bolsa: Node = jogador.get_node_or_null("Inventario")

	if bolsa == null or not bolsa.has_method("adicionar"):

		return false

	if not bool(bolsa.call("adicionar", id_item, 1)):

		return false

	_quantidade -= 1
	var indice: int = _ativos[_quantidade]

	if _animacoes[indice] != null and _animacoes[indice].is_valid():

		_animacoes[indice].kill()

	_animacoes[indice] = null
	var imagem: Sprite2D = _imagens[indice]
	var efeito: Node2D = EFEITO.new() as Node2D
	var destino: Node = imagem.get_parent()

	destino.add_child(efeito)
	destino.move_child(efeito, imagem.get_index() + 1)
	# A posição na árvore conserva a sobreposição da folha original.
	efeito.call("iniciar", imagem, tempo_manter_forma, duracao_dispersao, velocidade_dispersao, limite_particulas)
	_imagens[indice].hide()
	_imagens[indice].modulate = Color.WHITE
	_restante = maxf(segundos_regeneracao, 0.01)
	_reacoes[indice] = 0.0
	_tocar_som()
	ramo_coletado.emit(id_item)

	return true


# Recuperar a folha coletada
# ---------------------
# Restaura a mesma textura e posição com uma transição suave de opacidade.
func _recuperar(indice: int) -> void:

	var imagem: Sprite2D = _imagens[indice]
	_imagens[indice].show()
	_imagens[indice].modulate = Color(1.0, 1.0, 1.0, 0.0)
	var animacao: Tween = create_tween()
	_animacoes[indice] = animacao
	animacao.tween_property(imagem, "modulate:a", 1.0, duracao_reaparecer).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Tocar a coleta
# ---------------------
# Permite coletas seguidas usando o mesmo nó de áudio.
func _tocar_som() -> void:

	if som_coleta == null:

		return

	var audio: AudioStreamPlayer2D = $SomColeta
	audio.stream = som_coleta
	audio.bus = barramento_som if AudioServer.get_bus_index(barramento_som) >= 0 else &"Master"
	audio.volume_db = volume_coleta_db
	audio.play()


func exportar_estado_save() -> Dictionary:
	return {"quantidade": _quantidade, "restante": maxf(0.0, _restante)}

func importar_estado_save(dados: Dictionary) -> void:
	if _imagens.is_empty():
		return
	_quantidade = clampi(int(dados.get("quantidade", _ativos.size())), 0, _ativos.size())
	_restante = maxf(0.0, float(dados.get("restante", 0.0)))
	for i in range(_imagens.size()):
		if _animacoes[i] != null and _animacoes[i].is_valid():
			_animacoes[i].kill()
		_imagens[i].visible = _ativos.has(i) and _ativos.find(i) < _quantidade
		_imagens[i].modulate = Color.WHITE
