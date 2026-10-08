extends CharacterBody2D

# Configurações de Movimentação
@export var velocidade_andar: float = 180.0
@export var velocidade_correr: float = 320.0
@export var forca_pulo: float = -600.0

var esta_correndo: bool = false

@onready var sprite: AnimatedSprite2D = find_child("Sprite", true, false) as AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# Busca o nó do lenço para verificar se o gancho está ativo
	var lenco = find_child("PontoOrigem", true, false)
	var em_gancho: bool = (lenco != null and lenco.estado_atual == lenco.EstadoLenco.GANCHO)

	# 1. Aplica a Gravidade Padrão
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Pulo (Permitido apenas quando estiver pisando no chão)
	if Input.is_action_just_pressed("pular") and is_on_floor():
		velocity.y = forca_pulo

	# 3. Alternar Corrida (Ação 'correr' associada ao Caps Lock ou Shift)
	if Input.is_action_just_pressed("correr"):
		esta_correndo = !esta_correndo

	var vel_alvo := velocidade_correr if esta_correndo else velocidade_andar

	# 4. Movimentação Horizontal (A / D)
	# Permite andar se estiver no chão (mesmo preso pelo gancho) OU se o gancho não estiver ativo
	if is_on_floor() or not em_gancho:
		var direction := Input.get_axis("mover_esquerda", "mover_direita")
		if direction != 0:
			velocity.x = move_toward(velocity.x, direction * vel_alvo, vel_alvo * 8.0 * delta)
			if sprite:
				sprite.flip_h = (direction < 0)
		else:
			velocity.x = move_toward(velocity.x, 0.0, vel_alvo * 10.0 * delta)

	# Aplica o movimento respeitando as colisões com o cenário
	move_and_slide()
	atualizar_animacao()

func atualizar_animacao() -> void:
	if not sprite:
		return
		
	if not is_on_floor():
		if sprite.sprite_frames.has_animation("pular"):
			sprite.play("pular")
	elif abs(velocity.x) > 10.0:
		if esta_correndo and sprite.sprite_frames.has_animation("correr"):
			sprite.play("correr")
		elif sprite.sprite_frames.has_animation("andar"):
			sprite.play("andar")
	else:
		if sprite.sprite_frames.has_animation("parado"):
			sprite.play("parado")
