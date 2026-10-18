extends Node

func _ready() -> void:
	_prender_mouse()
	# Descomente para a tela cheia cobrir também a barra de tarefas:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _notification(what: int) -> void:
	# Ao voltar para o jogo (por exemplo depois de Alt+Tab), prende o mouse de novo
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_prender_mouse()

func _prender_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
