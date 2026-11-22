extends Sprite2D
## Um balanco independente por folha/caule; a origem do ramo fica parada.

@export_range(0.1, 3.0, 0.05) var velocidade: float = 0.85
@export_range(0.0, 6.0, 0.1) var amplitude_graus: float = 2.0
@export_range(0.0, 6.0, 0.1) var deslocamento_horizontal: float = 0.65
@export var fase: float = 0.0

var _posicao_inicial: Vector2
var _rotacao_inicial: float
var _tempo: float = 0.0


func _ready() -> void:
	_posicao_inicial = position
	_rotacao_inicial = rotation_degrees
	_tempo = fase


func _process(delta: float) -> void:
	if not visible:
		return
	_tempo += delta * velocidade
	rotation_degrees = _rotacao_inicial + sin(_tempo) * amplitude_graus
	position = _posicao_inicial + Vector2(sin(_tempo * 0.67) * deslocamento_horizontal, 0.0)
