# ===== BONECA SIMPLES DE RESERVA =====
# Só é usada se você NÃO atribuir a cena Player em "cena_boneca" no nó Teaser.
# Com a cena Player atribuída, este script não é usado.
class_name TeaserBoneca
extends CharacterBody2D

@export var velocidade_andar: float = 120.0
@export var aceleracao: float = 900.0
@export var atrito: float = 1400.0

func _eixo_horizontal() -> float:
	var esq: String = "mover_esquerda" if InputMap.has_action("mover_esquerda") else "ui_left"
	var dir: String = "mover_direita" if InputMap.has_action("mover_direita") else "ui_right"
	var eixo: float = Input.get_axis(esq, dir) + Input.get_axis("ui_left", "ui_right")
	return clampf(eixo, -1.0, 1.0)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var dir: float = _eixo_horizontal()
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * velocidade_andar, aceleracao * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, atrito * delta)
	move_and_slide()
