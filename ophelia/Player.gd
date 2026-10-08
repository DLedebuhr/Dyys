extends CharacterBody2D

# --- CONFIGURAÇÕES DE MOVIMENTAÇÃO ---
@export_group("Velocidade")
@export var velocidade_andar: float = 160.0
@export var velocidade_correr: float = 320.0
@export var velocidade_agachado: float = 80.0
@export var aceleracao: float = 1800.0
@export var atrito: float = 2000.0

@export_group("Pulo")
@export var forca_pulo: float = -680.0
@export var gravidade_multiplicador_queda: float = 1.5 # Queda mais pesada/agradável

@export_group("Assistentes de Pulo (Coyote & Buffer)")
@export var coyote_time_limite: float = 0.15 # Segundos para pular após cair da plataforma
@export var jump_buffer_limite: float = 0.15 # Segundos de registro do pulo antes de tocar o chão

# --- NÓS E REFERÊNCIAS ---
@onready var colisor_corpo: CollisionShape2D = $CollisionShape2D
@onready var raycast_teto: RayCast2D = $RayCast2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var lenco = find_child("PontoOrigem", true, false) # Guardado uma vez só

# --- VARIÁVEIS DE ESTADO INTERNO ---
var esta_correndo: bool = false
var esta_agachado: bool = false
var esta_levantando: bool = false

# Contadores dos assistentes de pulo
var tempo_coyote: float = 0.0
var tempo_jump_buffer: float = 0.0

func _physics_process(delta: float) -> void:
	_atualizar_temporizadores(delta)
	_processar_inputs_estado()
	_aplicar_gravidade(delta)
	_processar_pulo()
	_processar_movimento_horizontal(delta)
	move_and_slide()
	_atualizar_animacoes()

# --- CONSULTAS AO LENÇO ---
func _em_gancho() -> bool:
	return lenco != null and lenco.estado_atual == lenco.EstadoLenco.GANCHO

# Corda tensa no ar = balanço (o lenço controla o movimento horizontal)
func _balancando() -> bool:
	return _em_gancho() and lenco.corda_esticada and not is_on_floor()

# --- LÓGICA DE TEMPORIZADORES ---
func _atualizar_temporizadores(delta: float) -> void:
	# Coyote Time: permite pular pouco depois de deixar uma plataforma
	if is_on_floor():
		tempo_coyote = coyote_time_limite
	else:
		tempo_coyote -= delta

	# Jump Buffer: guarda a intenção de pulo pouco antes de tocar o chão
	if Input.is_action_just_pressed("pular"):
		tempo_jump_buffer = jump_buffer_limite
	else:
		tempo_jump_buffer -= delta

# --- LÓGICA DE ESTADOS (Correr em toggle / Sentar e Levantar em toggle) ---
func _processar_inputs_estado() -> void:
	if Input.is_action_just_pressed("correr"):
		esta_correndo = !esta_correndo

	if Input.is_action_just_pressed("agachar") and is_on_floor():
		var tem_teto_acima := raycast_teto.is_colliding() if raycast_teto else false

		if esta_agachado:
			# Só levanta se não houver teto no caminho
			if not tem_teto_acima:
				esta_agachado = false
				esta_levantando = true
				if sprite and sprite.sprite_frames.has_animation("levantar"):
					sprite.play("levantar")
		else:
			esta_agachado = true
			esta_levantando = false
			if sprite and sprite.sprite_frames.has_animation("sentar"):
				sprite.play("sentar")

func _definir_estado_agachado(agachar: bool) -> void:
	esta_agachado = agachar

# --- GRAVIDADE E PULO ---
func _aplicar_gravidade(delta: float) -> void:
	if not is_on_floor():
		var grav := get_gravity().y
		# Queda pesada só fora do balanço (no balanço a gravidade é simétrica)
		if velocity.y > 0 and not _balancando():
			velocity.y += grav * gravidade_multiplicador_queda * delta
		else:
			velocity.y += grav * delta

func _processar_pulo() -> void:
	# O pulo é acionado se houver registro no Buffer E no Coyote Time
	if tempo_jump_buffer > 0.0 and tempo_coyote > 0.0:
		velocity.y = forca_pulo
		tempo_jump_buffer = 0.0 # Consome o buffer
		tempo_coyote = 0.0      # Consome o coyote

		# Cancela o estado de agachar/sentar ao pular
		if esta_agachado and not (raycast_teto and raycast_teto.is_colliding()):
			_definir_estado_agachado(false)

	# Pulo variável: corta a altura se soltar a tecla no ar
	if Input.is_action_just_released("pular") and velocity.y < 0.0:
		velocity.y *= 0.5

# --- MOVIMENTO HORIZONTAL ---
func _processar_movimento_horizontal(delta: float) -> void:
	# Sentado no chão: só desacelera
	if esta_agachado and is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, atrito * delta)
		return

	var direcao := Input.get_axis("mover_esquerda", "mover_direita")

	# Balançando na corda esticada: sem atrito nem aceleração própria,
	# o lenço cuida do embalo. Só vira o sprite.
	if _balancando():
		if direcao != 0.0 and sprite:
			sprite.flip_h = (direcao < 0.0)
		return

	var vel_maxima := velocidade_correr if esta_correndo else velocidade_andar

	if direcao != 0.0:
		velocity.x = move_toward(velocity.x, direcao * vel_maxima, aceleracao * delta)
		if sprite:
			sprite.flip_h = (direcao < 0.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, atrito * delta)

# --- ANIMAÇÕES ---
func _atualizar_animacoes() -> void:
	if not sprite or not sprite.sprite_frames:
		return

	# NO AR: balançar (gancho) ou pular. Uma única decisão, sem sobrescrever.
	if not is_on_floor():
		esta_levantando = false
		if _em_gancho() and sprite.sprite_frames.has_animation("balancar"):
			sprite.play("balancar")
		elif sprite.sprite_frames.has_animation("pular"):
			sprite.play("pular")
		return

	# Espera a animação 'levantar' terminar (e não trava se ela não existir)
	if esta_levantando:
		if sprite.animation != "levantar" or not sprite.is_playing():
			esta_levantando = false
		else:
			return

	if esta_agachado:
		# Só toca 'sentar' se ainda não estiver tocando (evita reiniciar o frame 1)
		if sprite.sprite_frames.has_animation("sentar") and sprite.animation != "sentar":
			sprite.play("sentar")

	elif absf(velocity.x) > 10.0:
		if esta_correndo and sprite.sprite_frames.has_animation("correr"):
			sprite.play("correr")
		elif sprite.sprite_frames.has_animation("andar"):
			sprite.play("andar")

	else:
		if sprite.sprite_frames.has_animation("parado"):
			sprite.play("parado")
