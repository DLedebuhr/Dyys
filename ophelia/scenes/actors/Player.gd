extends CharacterBody2D

# --- CONFIGURAÇÕES DE MOVIMENTAÇÃO ---
@export_group("Velocidade")
@export var velocidade_andar: float = 160.0
@export var velocidade_correr: float = 500.0
@export var aceleracao: float = 1800.0
@export var atrito: float = 2000.0

@export_group("Pulo")
@export var forca_pulo: float = -680.0
@export var gravidade_multiplicador_queda: float = 1.5 # Queda mais pesada/agradável

@export_group("Assistentes de Pulo (Coyote & Buffer)")
@export var coyote_time_limite: float = 0.15 # Segundos para pular após cair da plataforma
@export var jump_buffer_limite: float = 0.15 # Segundos de registro do pulo antes de tocar o chão

@export_group("Planar")
@export var planar_gravidade: float = 0.25 # Fração da gravidade normal durante a planagem
@export var velocidade_queda_planando: float = 80.0 # Velocidade máxima de queda planando
@export var planar_segurando_tecla: bool = true # true: planar enquanto segura | false: aperta de novo para cancelar

# --- NÓS E REFERÊNCIAS ---
@onready var colisor_corpo: CollisionShape2D = $CollisionShape2D
@onready var raycast_teto: RayCast2D = $RayCast2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var lenco = find_child("PontoOrigem", true, false) # Guardado uma vez só

# --- VARIÁVEIS DE ESTADO INTERNO ---
# Correr: CapsLock ligado = corre | desligado = caminha (alterna a cada toque)
var esta_correndo: bool = false
var esta_sentada: bool = false
var esta_levantando: bool = false

# Estado do planar (a animação continua sendo a de pulo; quem anima é o nó Asas)
var planando: bool = false

# false = animações "...Base" (sem chapéu) | true = animações "...Chapeu"
var usando_chapeu: bool = false

# Contadores dos assistentes de pulo
var tempo_coyote: float = 0.0
var tempo_jump_buffer: float = 0.0

func _physics_process(delta: float) -> void:
	_atualizar_temporizadores(delta)
	_processar_inputs_estado()
	_processar_planar()
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
	if Input.is_action_just_pressed("ControlePular"):
		tempo_jump_buffer = jump_buffer_limite
	else:
		tempo_jump_buffer -= delta

# --- LÓGICA DE ESTADOS (Correr em toggle / Sentar e Levantar em toggle) ---
func _processar_inputs_estado() -> void:
	if Input.is_action_just_pressed("ControleCorrer"):
		esta_correndo = !esta_correndo

	if Input.is_action_just_pressed("ControleSentarLevantar") and is_on_floor():
		var tem_teto_acima := raycast_teto.is_colliding() if raycast_teto else false

		if esta_sentada:
			# Só levanta se não houver teto no caminho
			if not tem_teto_acima:
				esta_sentada = false
				esta_levantando = true
				_tocar("Levantar", true)
		else:
			esta_sentada = true
			esta_levantando = false
			_tocar("Sentar", true)

func _definir_estado_sentada(sentar: bool) -> void:
	esta_sentada = sentar

# --- PLANAR ---
# Aperta "ControlePular" de novo no ar (sem estar preso ao gancho) para começar a planar.
func _processar_planar() -> void:
	if planando:
		if is_on_floor():
			_encerrar_planar()  # Pousou
		elif _em_gancho():
			_encerrar_planar()  # Prendeu o gancho: cancela
		elif planar_segurando_tecla and not Input.is_action_pressed("ControlePular"):
			_encerrar_planar()  # Soltou a tecla: volta a cair normalmente
		elif not planar_segurando_tecla and Input.is_action_just_pressed("ControlePular"):
			_encerrar_planar()  # Modo toggle: apertou de novo para cancelar
			tempo_jump_buffer = 0.0
		return

	# Só começa fora do chão, depois do coyote time (senão seria um pulo normal) e sem gancho
	if Input.is_action_just_pressed("ControlePular") \
			and not is_on_floor() \
			and tempo_coyote <= 0.0 \
			and not _em_gancho():
		_iniciar_planar()

func _iniciar_planar() -> void:
	planando = true
	tempo_jump_buffer = 0.0 # Não deixa o pulo "guardado" disparar ao pousar
	velocity.y = maxf(velocity.y, 0.0) # Se estava subindo, começa a planar do topo
	esta_levantando = false

func _encerrar_planar() -> void:
	planando = false

# --- GRAVIDADE E PULO ---
func _aplicar_gravidade(delta: float) -> void:
	if not is_on_floor():
		var grav := get_gravity().y

		# Planando: gravidade reduzida e velocidade de queda limitada
		if planando:
			velocity.y = minf(velocity.y + grav * planar_gravidade * delta, velocidade_queda_planando)
			return

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

		# Cancela o estado de sentada ao pular
		if esta_sentada and not (raycast_teto and raycast_teto.is_colliding()):
			_definir_estado_sentada(false)

	# Pulo variável: corta a altura se soltar a tecla no ar
	if Input.is_action_just_released("ControlePular") and velocity.y < 0.0:
		velocity.y *= 0.5

# --- MOVIMENTO HORIZONTAL ---
func _processar_movimento_horizontal(delta: float) -> void:
	# Sentada no chão: só desacelera
	if esta_sentada and is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, atrito * delta)
		return

	var direcao := Input.get_axis("ControleAndarEsquerda", "ControleAndarDireita")

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

# --- CHAPÉU E NOMES DE ANIMAÇÃO ---
func definir_chapeu(usar: bool) -> void:
	usando_chapeu = usar

# "Andar" -> "AndarBase" ou "AndarChapeu", conforme o chapéu
func _nome_anim(nome: String) -> String:
	return nome + ("Chapeu" if usando_chapeu else "Base")

func _tem_anim(nome: String) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(nome)

# Toca a animação na versão certa. reiniciar = true recomeça mesmo se já estiver tocando.
func _tocar(nome: String, reiniciar: bool = false) -> void:
	var alvo := _nome_anim(nome)
	if not _tem_anim(alvo):
		return
	if sprite.animation == alvo and not reiniciar:
		return
	# Trocou só o chapéu (mesma animação, outra versão)? Mantém o frame em vez de recomeçar.
	var mesma_animacao := not reiniciar and String(sprite.animation).begins_with(nome)
	var frame_antes := sprite.frame
	sprite.play(alvo)
	if mesma_animacao:
		var ultimo := sprite.sprite_frames.get_frame_count(alvo) - 1
		sprite.set_frame_and_progress(mini(frame_antes, ultimo), 0.0)

# --- ANIMAÇÕES ---
func _atualizar_animacoes() -> void:
	if not sprite or not sprite.sprite_frames:
		return

	# NO AR: pular, planar e balançar usam a mesma animação de pulo
	# (o planar ganha o efeito das asas pelo nó Asas)
	if not is_on_floor():
		esta_levantando = false
		_tocar("Pular")
		return

	# Espera a animação 'Levantar' terminar
	if esta_levantando:
		if sprite.animation != _nome_anim("Levantar") or not sprite.is_playing():
			esta_levantando = false
		else:
			return

	if esta_sentada:
		_tocar("Sentar")
	elif absf(velocity.x) > 10.0:
		_tocar("Correr" if esta_correndo else "Andar")
	else:
		_tocar("Parado")

# TEMPORÁRIO: H alterna o chapéu para testar. Remover quando o chapéu for ligado ao jogo.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		definir_chapeu(not usando_chapeu)
