extends Camera2D

@export var posicao_inicial: Vector2 = Vector2(963.0, -2419.0)     # Onde a câmera começa (em cima)
@export var posicao_final: Vector2 = Vector2(963.0, 600)     # Onde ela trava (embaixo)
@export var atraso: float = 1                          # Espera (s) antes de começar a descer
@export var duracao: float = 5                        # Tempo (s) da descida

func _ready() -> void:
	position_smoothing_enabled = false     # Senão o smoothing briga com o movimento
	global_position = posicao_inicial
	make_current.call_deferred()           # Garante que esta é a câmera ativa, e não a do Player

	await get_tree().create_timer(atraso).timeout

	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "global_position", posicao_final, duracao)
