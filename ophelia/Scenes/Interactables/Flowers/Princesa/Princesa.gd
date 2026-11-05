@tool
extends "../Comum/PlantaFlores.gd"


@export_group("Movimento pendente")
@export var vento_ativo: bool = true
@export var mostrar_vento_no_editor: bool = false
@export_range(0.0, 15.0, 0.5) var amplitude_vento: float = 3.0
@export_range(0.1, 5.0, 0.1) var velocidade_vento: float = 1.0
@export_range(0.0, 15.0, 0.5) var reacao_coleta: float = 3.0

var _galhos: Array[Line2D] = []
var _originais: Array[PackedVector2Array] = []
var _reacoes: Array[float] = []
var _caule_original: PackedVector2Array = PackedVector2Array()
var _tempo: float = 0.0


# Preparar a planta
# ---------------------
# Guarda as curvas pendentes e prepara a coleta compartilhada.
func _ready() -> void:

	super._ready()
	_caule_original = $Caule.points.duplicate()

	for filho in $Galhos.get_children():

		if filho is Line2D:

			_galhos.append(filho)
			_originais.append(filho.points.duplicate())
			_reacoes.append(100.0)


# Animar o caule e os galhos pendentes
# ---------------------
# Move a junção com o caule e aplica um balanço suave nas flores e pontos brancos.
func _atualizar_movimento(delta: float) -> void:

	if Engine.is_editor_hint() and not mostrar_vento_no_editor:

		return

	if _caule_original.is_empty():

		return

	_tempo += delta
	var vento_base: float = sin(_tempo * velocidade_vento) * amplitude_vento if vento_ativo else 0.0
	var caule: PackedVector2Array = _caule_original.duplicate()

	for j in range(caule.size()):

		var peso: float = float(j) / maxf(caule.size() - 1, 1.0)
		caule[j].x += vento_base * peso * peso

	$Caule.points = caule
	$Juncao.position = Vector2(vento_base, 0.0)

	for i in range(_galhos.size()):

		_reacoes[i] += delta
		var pontos: PackedVector2Array = _originais[i].duplicate()
		var reacao: float = sin(_reacoes[i] * 12.0) * exp(-_reacoes[i] * 3.0) * reacao_coleta
		var balanco: float = sin(_tempo * velocidade_vento + float(i) * 0.4) * amplitude_vento if vento_ativo else 0.0

		for j in range(pontos.size()):

			var peso: float = float(j) / maxf(pontos.size() - 1, 1.0)
			pontos[j].x += vento_base + (balanco + reacao) * peso * peso

		_galhos[i].points = pontos
		_flores[i].position = pontos[-1]
		_flores[i].rotation = clampf((balanco + reacao) * 0.008, -0.15, 0.15)


# Reagir à coleta
# ---------------------
# Reinicia o balanço apenas no galho da flor recolhida.
func _apos_coleta(indice: int) -> void:

	_reacoes[indice] = 0.0
