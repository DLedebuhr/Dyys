@tool
extends "../Comum/PlantaFlores.gd"

@export_group("Movimento da planta")
@export var vento_ativo: bool = true
@export var mostrar_vento_no_editor: bool = false
@export_range(0.0, 20.0, 0.5) var amplitude_vento: float = 2.0
@export_range(0.1, 5.0, 0.1) var velocidade_vento: float = 1.2
@export_range(0.0, 20.0, 0.5) var reacao_coleta: float = 2.0

var _formas: Array[Polygon2D] = []
var _originais: Array[PackedVector2Array] = []
var _posicoes: Array[Vector2] = []
var _tempo: float = 0.0
var _tempo_reacao: float = 100.0
const ALTURA: float = 253.0


# Preparar a planta
# ---------------------
# Guarda o desenho original e inicia a coleta compartilhada.
func _ready() -> void:

	super._ready()

	for filho in $Base.get_children():

		if filho is Polygon2D:

			_formas.append(filho)
			_originais.append(filho.polygon.duplicate())

	for flor in _flores:

		_posicoes.append(flor.position)


# Calcular o balanço
# ---------------------
# Mantém o pé fixo e aumenta o movimento na parte superior.
func _deslocamento(ponto: Vector2) -> float:

	var peso: float = pow(clampf(-ponto.y / ALTURA, 0.0, 1.0), 1.7)
	var vento: float = sin(_tempo * velocidade_vento + ponto.x * 0.002) * amplitude_vento if vento_ativo else 0.0
	var reacao: float = sin(_tempo_reacao * 18.0) * exp(-_tempo_reacao * 4.0) * reacao_coleta

	return (vento + reacao) * peso


# Atualizar o movimento
# ---------------------
# Faz caules, folhas e flores acompanharem o mesmo balanço.
func _atualizar_movimento(delta: float) -> void:

	if Engine.is_editor_hint() and not mostrar_vento_no_editor:

		return

	_tempo += delta
	_tempo_reacao += delta

	for i in range(_formas.size()):

		var pontos: PackedVector2Array = _originais[i].duplicate()

		for j in range(pontos.size()):

			pontos[j].x += _deslocamento(_originais[i][j])

		_formas[i].polygon = pontos

	for i in range(_posicoes.size()):

		_flores[i].position = _posicoes[i] + Vector2(_deslocamento(_posicoes[i]), 0.0)


# Reagir à coleta
# ---------------------
# Produz um balanço curto depois de retirar uma flor.
func _apos_coleta(_indice: int) -> void:

	_tempo_reacao = 0.0
