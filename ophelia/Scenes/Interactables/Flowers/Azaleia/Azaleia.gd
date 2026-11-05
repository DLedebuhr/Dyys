@tool
extends "../Comum/PlantaFlores.gd"


@export_group("Movimento da azaleia")
@export var vento_ativo: bool = true
@export var mostrar_vento_no_editor: bool = false
@export_range(0.0, 20.0, 0.5) var amplitude_vento: float = 3.0
@export_range(0.1, 5.0, 0.1) var velocidade_vento: float = 1.2
@export_range(0.0, 20.0, 0.5) var reacao_coleta: float = 3.0

var _galhos: Array[Line2D] = []
var _originais: Array[PackedVector2Array] = []
var _tempos_reacao: Array[float] = []
var _tempo: float = 0.0


# Preparar os galhos
# ---------------------
# Guarda as curvas e prepara a coleta pelo sistema compartilhado.
func _ready() -> void:

	super._ready()

	for filho in $Galhos.get_children():

		if filho is Line2D:

			_galhos.append(filho)
			_originais.append(filho.points.duplicate())
			_tempos_reacao.append(100.0)


# Atualizar o movimento
# ---------------------
# Mantém a base no lugar e faz a flor acompanhar a ponta do galho.
func _atualizar_movimento(delta: float) -> void:

	if Engine.is_editor_hint() and not mostrar_vento_no_editor:

		return

	_tempo += delta

	for i in range(_galhos.size()):

		_tempos_reacao[i] += delta
		var pontos: PackedVector2Array = _originais[i].duplicate()
		var reacao: float = sin(_tempos_reacao[i] * 18.0) * exp(-_tempos_reacao[i] * 4.0) * reacao_coleta

		for j in range(pontos.size()):

			var peso: float = pow(float(j) / maxf(pontos.size() - 1, 1.0), 1.7)
			var vento: float = sin(_tempo * velocidade_vento + float(i) * 0.3 + peso * 0.5) * amplitude_vento if vento_ativo else 0.0
			pontos[j].x += (vento + reacao) * peso

		_galhos[i].points = pontos
		_flores[i].position = pontos[-1]
		_flores[i].rotation = (_originais[i][-1] - _originais[i][-2]).angle_to(pontos[-1] - pontos[-2])


# Reagir à coleta
# ---------------------
# Aplica um balanço curto no galho da flor retirada.
func _apos_coleta(indice: int) -> void:

	_tempos_reacao[indice] = 0.0
