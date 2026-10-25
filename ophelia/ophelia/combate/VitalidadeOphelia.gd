extends Node
signal vida_alterada(atual: int, maxima: int)
signal dano_recebido(quantidade: int, origem: Vector2)
signal dano_bloqueado(quantidade: int, origem: Vector2)
signal morreu()
@export_range(1, 10000, 1) var vida_maxima: int = 100
@export_range(0.0, 5.0, 0.05) var invulnerabilidade_apos_dano: float = 0.5
var vida_atual: int = 100
var _invulnerabilidade: float = 0.0

func _ready() -> void:
	vida_atual = vida_maxima

func atualizar(delta: float) -> void:
	_invulnerabilidade = maxf(_invulnerabilidade - delta, 0.0)

func esta_viva() -> bool:
	return vida_atual > 0

func receber_dano(quantidade: int, origem: Vector2, defendendo: bool) -> bool:
	if quantidade <= 0 or not esta_viva():
		return false
	if defendendo:
		dano_bloqueado.emit(quantidade, origem)
		return false
	if _invulnerabilidade > 0.0:
		return false
	vida_atual = maxi(0, vida_atual - quantidade)
	_invulnerabilidade = invulnerabilidade_apos_dano
	vida_alterada.emit(vida_atual, vida_maxima)
	dano_recebido.emit(quantidade, origem)
	if vida_atual == 0:
		morreu.emit()
	return true

func restaurar() -> void:
	vida_atual = vida_maxima
	_invulnerabilidade = 0.0
	vida_alterada.emit(vida_atual, vida_maxima)
