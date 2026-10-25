extends Node
@onready var corpo = owner
func _unhandled_input(event: InputEvent) -> void:
	if not corpo.em_modo_debug() or (event is InputEventKey and event.echo):
		return
	if event.is_action_pressed("ControleChapeuDebug"):
		corpo.definir_chapeu(not corpo.usando_chapeu)
	elif event.is_action_pressed("ControleIrritadaDebug"):
		corpo.tocar_reacao(corpo.REACAO_IRRITADA)
	elif event.is_action_pressed("ControleAgradecerDebug"):
		corpo.agradecer_ajuda()
	elif event.is_action_pressed("ControleTeleporteDebug"):
		corpo.teletransportar(corpo.get_global_mouse_position())
