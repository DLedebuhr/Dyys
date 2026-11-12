extends Marker2D

@export var acao_interagir: StringName = &"ControleInteragir"
@export_range(10.0, 500.0, 1.0) var distancia_coleta: float = 100.0

var _jogador: CharacterBody2D
@onready var _fonte: Node = get_node("../..")


# Registrar a bacia
# ---------------------
# Permite que o seletor existente compare a proximidade desta bacia com os outros itens.
func _ready() -> void:

	add_to_group("coletaveis_ophelia")


# Verificar a aproximação
# ---------------------
# A falta de cápsulas não oculta a mensagem; somente impede o preenchimento.
func pode_interagir(jogador: CharacterBody2D) -> bool:

	if not is_instance_valid(jogador) or not is_instance_valid(_fonte):

		return false

	if get_tree().paused or not jogador.is_in_group("jogador"):

		return false

	if global_position.distance_to(jogador.global_position) > distancia_coleta:

		return false

	var vida: Node = jogador.get_node_or_null("Vitalidade")

	if vida == null or not vida.has_method("esta_viva") or not bool(vida.call("esta_viva")):

		return false

	_jogador = jogador

	return true


# Informar a ação disponível
# ---------------------
# Delega à fonte a escolha entre encher a cápsula e informar sua falta.
func obter_mensagem_interacao() -> String:

	return str(_fonte.call("obter_mensagem", _jogador))


# Preencher uma unidade
# ---------------------
# Revalida a distância no momento do comando e compartilha a mesma fonte entre as bacias.
func interagir(jogador: CharacterBody2D) -> bool:

	if not pode_interagir(jogador):

		return false

	return bool(_fonte.call("encher_capsula", jogador))
