extends CharacterBody2D

const SPEED = 200.0
const JUMP_VELOCITY = -700.0

# Confirme se o nome do nó na sua árvore é $AnimatedSprite2D
@onready var sprite: AnimatedSprite2D = $Sprite

func _physics_process(delta: float) -> void:
	# 1. Aplica a gravidade se o personagem estiver no ar
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Pulo com a tecla W ("pular")
	if Input.is_action_just_pressed("pular") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 3. Direção horizontal com A e D ("mover_esquerda", "mover_direita")
	var direction := Input.get_axis("mover_esquerda", "mover_direita")
	if direction != 0:
		velocity.x = direction * SPEED
		# Inverte a imagem: vira para a esquerda se for negativo (-1)
		sprite.flip_h = (direction < 0)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# 4. Executa a movimentação
	move_and_slide()

	# 5. Toca as animações
	atualizar_animacao()

func atualizar_animacao() -> void:
	if not is_on_floor():
		sprite.play("pular")
	elif velocity.x != 0:
		sprite.play("andar")
	else:
		sprite.play("parado")
