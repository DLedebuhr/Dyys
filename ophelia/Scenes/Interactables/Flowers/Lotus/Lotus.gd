@tool
extends "../Comum/PlantaFlores.gd"


@export_group("Movimento da flor")
@export var vento_ativo: bool = true
@export var mostrar_vento_no_editor: bool = false
@export_range(0.0, 5.0, 0.1) var inclinacao_graus: float = 1.0
@export_range(0.1, 5.0, 0.1) var velocidade_vento: float = 1.2

var _tempo: float = 0.0


# Animar somente a flor
# ---------------------
# Mantém a folha verde no lugar e inclina suavemente a flor sobre ela.
func _atualizar_movimento(delta: float) -> void:

	if Engine.is_editor_hint() and not mostrar_vento_no_editor:

		return

	_tempo += delta
	var encaixe: Node2D = get_node_or_null("Flores/Flor1") as Node2D

	if encaixe == null:

		return

	encaixe.rotation = sin(_tempo * velocidade_vento) * deg_to_rad(inclinacao_graus) if vento_ativo else 0.0
