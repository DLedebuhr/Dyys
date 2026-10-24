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

@export_group("Reações")
@export var duracao_irritada: float = 2.0          # Segundos (a animação repete até o tempo acabar)
@export var duracao_agradecer: float = 2.0         # Segundos
@export var tempo_parada: float = 20.0             # Segundos sem agir até a reação "Parada"
@export var duracao_parada: float = 0.0            # 0 = dura até ela agir de novo
@export var espera_maxima_reacao: float = 3.0      # Quanto um pedido de reação espera ela ficar livre
@export_flags_2d_physics var mascara_sensor: int = 1   # Camadas das áreas que ela detecta (AreaPrePortal)
@export var imprimir_reacoes: bool = true          # Escreve na Saída cada reação (para testar)

@export_subgroup("Brilho da batida de pé (Irritada)")
@export var brilho_batida_ativo: bool = true
@export var frame_batida_pe: int = 1               # Quadro da Irritada em que o pé bate no chão (-1 = em todo quadro)
@export var deslocamento_pe_batida: Vector2 = Vector2.ZERO  # Ajuste até o pé que bate (o X espelha com ela)
@export var cor_brilho_batida: Color = Color(1.0, 0.95, 0.6)
@export var quantidade_brilho_batida: int = 10
@export var alcance_brilho_batida: float = 60.0    # Velocidade com que as faíscas se espalham
@export var duracao_brilho_batida: float = 0.5
@export var tamanho_brilho_batida: float = 0.7
@export_range(0.0, 180.0) var espalhamento_brilho_batida: float = 75.0  # Graus em volta da direção "para cima"

# --- NÓS E REFERÊNCIAS ---
@onready var colisor_corpo: CollisionShape2D = $CollisionShape2D
@onready var raycast_teto: RayCast2D = $RayCast2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var lenco = find_child("PontoOrigem", true, false) # Guardado uma vez só
@onready var habilidades: Habilidades = get_node_or_null("Habilidades") as Habilidades

# --- VARIÁVEIS DE ESTADO INTERNO ---
# Correr: CapsLock ligado = corre | desligado = caminha (alterna a cada toque)
var esta_correndo: bool = false
var esta_sentada: bool = false
var esta_levantando: bool = false

# Estado do planar (a animação continua sendo a de pulo; quem anima é o nó Asas)
var planando: bool = false

# false = animações "...Base" (sem chapéu) | true = animações "...Chapeu"
var usando_chapeu: bool = false

# --- REAÇÕES (Irritada, AgradecerAjuda, Parada): acontecem por interação, sem botões ---
const REACAO_IRRITADA: StringName = &"Irritada"
const REACAO_AGRADECER_AJUDA: StringName = &"AgradecerAjuda"
const REACAO_PARADA: StringName = &"Parada"

# Estas animações seguem a imagem original, sem espelhar para onde ela olha (a Transição espelha)
const ANIMACOES_SEM_ESPELHO := ["Irritada", "Agradecer", "Esperar"]

# Para onde ela está olhando. Fica guardado à parte do sprite, porque nas animações acima o
# sprite não espelha, mas ela volta a olhar para o mesmo lado quando a reação termina.
var olhando_esquerda: bool = false

var reacao_atual: StringName = &""      # Reação tocando agora (&"" = nenhuma)
var _reacao_tempo: float = 0.0          # Tempo restante da reação (conta depois da Transição)
var _reacao_na_transicao: bool = false  # true enquanto toca a Transição que antecede a reação
var _transicao_tempo: float = 0.0       # Tempo restante da Transição
var _reacao_pendente: StringName = &""  # Pedido esperando ela ficar livre
var _reacao_espera: float = 0.0         # Quanto tempo o pedido ainda espera
var _tempo_ocioso: float = 0.0          # Há quantos segundos ela está sem agir
var _avisou_sem_anim: Dictionary = {}   # Para avisar de animação faltando uma vez só
var _sensor: Area2D = null              # Detecta as áreas do cenário (AreaPrePortal)
var _tex_brilho: Texture2D = null       # Textura das faíscas (criada uma vez só)

# Contadores dos assistentes de pulo
var tempo_coyote: float = 0.0
var tempo_jump_buffer: float = 0.0

func _ready() -> void:
	add_to_group("jogador") # Os interativos reconhecem a personagem por este grupo
	if habilidades == null:
		push_warning("Player: falta o nó filho 'Habilidades'. Todas as habilidades ficam liberadas.")
	_criar_sensor()
	if sprite:
		sprite.frame_changed.connect(_ao_mudar_frame)

func _physics_process(delta: float) -> void:
	_atualizar_temporizadores(delta)
	_processar_reacoes(delta)
	_processar_inputs_estado()
	_processar_planar()
	_aplicar_gravidade(delta)
	_processar_pulo()
	_processar_movimento_horizontal(delta)
	move_and_slide()
	_atualizar_animacoes()
	_aplicar_espelho()

# --- CONSULTAS AO LENÇO ---
func _em_gancho() -> bool:
	# Gancho num ponto firme (parede, chão, objeto pesado). Num objeto leve a corda não segura a personagem.
	return lenco != null and lenco.estado_atual == lenco.EstadoLenco.GANCHO and not lenco.ancora_leve

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

	if Input.is_action_just_pressed("ControleSentarLevantar") and is_on_floor() and not _reacao_trava():
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
		elif not pode_usar(Habilidades.PLANAR):
			_encerrar_planar()  # A permissão acabou (ex.: o modo debug foi desligado)
		elif planar_segurando_tecla and not Input.is_action_pressed("ControlePular"):
			_encerrar_planar()  # Soltou a tecla: volta a cair normalmente
		elif not planar_segurando_tecla and Input.is_action_just_pressed("ControlePular"):
			_encerrar_planar()  # Modo toggle: apertou de novo para cancelar
			tempo_jump_buffer = 0.0
		return

	# Só começa fora do chão, depois do coyote time, sem gancho e se a habilidade estiver liberada
	if Input.is_action_just_pressed("ControlePular") \
			and not is_on_floor() \
			and tempo_coyote <= 0.0 \
			and not _em_gancho() \
			and pode_usar(Habilidades.PLANAR):
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
	# Durante Irritada/Agradecer ela fica parada: sem pulo
	if _reacao_trava():
		tempo_jump_buffer = 0.0
		return

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
	# Durante Irritada/Agradecer ela fica parada: só desacelera
	if _reacao_trava():
		velocity.x = move_toward(velocity.x, 0.0, atrito * delta)
		return

	# Sentada no chão: só desacelera
	if esta_sentada and is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, atrito * delta)
		return

	var direcao := Input.get_axis("ControleAndarEsquerda", "ControleAndarDireita")

	# Balançando na corda esticada: sem atrito nem aceleração própria,
	# o lenço cuida do embalo. Só vira o sprite.
	if _balancando():
		if direcao != 0.0:
			olhando_esquerda = (direcao < 0.0)
		return

	var vel_maxima := velocidade_correr if esta_correndo else velocidade_andar

	if direcao != 0.0:
		velocity.x = move_toward(velocity.x, direcao * vel_maxima, aceleracao * delta)
		olhando_esquerda = (direcao < 0.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, atrito * delta)

# --- HABILIDADES ---
# Pode usar? (permissão: vem do nó Habilidades)
func pode_usar(id: StringName) -> bool:
	return habilidades == null or habilidades.pode_usar(id)

# Está usando agora? (estado real; só para habilidades que duram)
func esta_em_uso(id: StringName) -> bool:
	match id:
		Habilidades.PLANAR:
			return planando
		Habilidades.CORRER:
			return esta_correndo
		Habilidades.SENTAR_LEVANTAR:
			return esta_sentada
		Habilidades.FIXAR_LENCO:
			return _em_gancho()
		Habilidades.ATAQUE_LENCO:
			return lenco != null and lenco.estado_atual == lenco.EstadoLenco.ATAQUE_Q
		Habilidades.DEFESA_LENCO:
			return lenco != null and lenco.estado_atual == lenco.EstadoLenco.DEFESA_E
		Habilidades.AGARRAR_OBJETO:
			return lenco != null and lenco.estado_atual == lenco.EstadoLenco.GANCHO and lenco.ancora_leve
	return false

# --- MODO DEBUG E TELEPORTE (só para desenvolvimento; jogadores não têm acesso) ---
func em_modo_debug() -> bool:
	return habilidades != null and habilidades.esta_em_modo_debug()

# Move a personagem para 'destino' (ponto do chão onde ficam os pés; com destino_e_dos_pes = false,
# é a origem do Player). Só funciona com o modo debug ligado. Futuramente: a tela de progresso chama isto.
func teletransportar(destino: Vector2, destino_e_dos_pes: bool = true) -> bool:
	if not em_modo_debug():
		push_warning("Player: teletransporte só funciona com o modo debug (666) ligado.")
		return false

	var origem_destino := destino
	if destino_e_dos_pes:
		origem_destino = destino - (_posicao_pes_global() - global_position)

	# Zera tudo o que estava em andamento
	cancelar_reacao()
	planando = false
	esta_levantando = false
	esta_sentada = false
	if lenco != null and lenco.has_method("soltar_tudo"):
		lenco.soltar_tudo()
	velocity = Vector2.ZERO
	tempo_coyote = 0.0
	tempo_jump_buffer = 0.0

	global_position = origem_destino
	if has_method("reset_physics_interpolation"):
		call("reset_physics_interpolation")
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		camera.reset_smoothing()   # A câmera pula junto, sem deslizar pelo mapa
	return true

# --- REAÇÕES ---
# Pontos de integração:
#   - AreaPrePortal (Area2D no cenário): ao entrar nela, ela fica irritada (o sensor é criado em _criar_sensor).
#   - Catálogo: ao fechar a tela depois de registrar uma flor, chame jogador.agradecer_ajuda().
#   - Parada: acontece sozinha, depois de 'tempo_parada' segundos sem agir.
func agradecer_ajuda() -> void:
	tocar_reacao(REACAO_AGRADECER_AJUDA)

# Pede uma reação. Se ela não estiver livre (no ar, sentada, usando o lenço...),
# o pedido espera até 'espera_maxima_reacao' segundos.
func tocar_reacao(id: StringName) -> void:
	if id != REACAO_IRRITADA and id != REACAO_AGRADECER_AJUDA and id != REACAO_PARADA:
		push_warning("Player: reação desconhecida '%s'." % id)
		return
	_reacao_pendente = id
	_reacao_espera = espera_maxima_reacao

# Interrompe qualquer reação (usado pelo voo de teste)
func cancelar_reacao() -> void:
	reacao_atual = &""
	_reacao_na_transicao = false
	_reacao_pendente = &""
	_tempo_ocioso = 0.0

func _processar_reacoes(delta: float) -> void:
	# "Agindo" = qualquer tecla ou botão apertado, andando ou fora do chão
	var agindo := Input.is_anything_pressed() or absf(velocity.x) > 10.0 or not is_on_floor()

	# 1) Reação em andamento
	if reacao_atual != &"" and _reacao_na_transicao:
		# Primeiro a Transição (meio termo, espelhada pela direção); depois a animação da reação
		if reacao_atual == REACAO_PARADA and agindo:
			_encerrar_reacao()
		else:
			_transicao_tempo -= delta
			if _transicao_tempo <= 0.0:
				_reacao_na_transicao = false
				_tocar(_anim_da_reacao(reacao_atual), true)
	elif reacao_atual == REACAO_PARADA:
		# A Parada acaba quando ela age (ou depois do tempo, se 'duracao_parada' > 0)
		if agindo:
			_encerrar_reacao()
		elif duracao_parada > 0.0:
			_reacao_tempo -= delta
			if _reacao_tempo <= 0.0:
				_encerrar_reacao()
	elif reacao_atual != &"":
		# Irritada e AgradecerAjuda duram o tempo configurado (ela fica parada durante)
		_reacao_tempo -= delta
		if _reacao_tempo <= 0.0:
			_encerrar_reacao()

	# 2) Pedido esperando ela ficar livre
	if _reacao_pendente != &"":
		_reacao_espera -= delta
		if _reacao_espera <= 0.0:
			_reacao_pendente = &""
		elif _pode_iniciar_reacao(_reacao_pendente, agindo):
			_iniciar_reacao(_reacao_pendente)
			_reacao_pendente = &""

	# 3) Parada: livre e sem agir por tempo suficiente
	if reacao_atual == &"" and _reacao_pendente == &"" and _livre_para_reagir() and not agindo:
		_tempo_ocioso += delta
		if _tempo_ocioso >= tempo_parada:
			_tempo_ocioso = 0.0
			tocar_reacao(REACAO_PARADA)
	else:
		_tempo_ocioso = 0.0

# Livre = em pé, no chão, sem planar e com o lenço em repouso
func _livre_para_reagir() -> bool:
	return is_on_floor() and not esta_sentada and not esta_levantando and not planando \
			and (lenco == null or lenco.estado_atual == lenco.EstadoLenco.REPOUSO)

# Prioridade: a Parada cede a qualquer outra reação; Irritada e AgradecerAjuda esperam a vez
func _prioridade(id: StringName) -> int:
	return 0 if id == REACAO_PARADA else 1

func _pode_iniciar_reacao(id: StringName, agindo: bool) -> bool:
	if id == REACAO_PARADA and agindo:
		return false
	if not _livre_para_reagir():
		return false
	return reacao_atual == &"" or _prioridade(id) > _prioridade(reacao_atual)

func _iniciar_reacao(id: StringName) -> void:
	reacao_atual = id
	_tempo_ocioso = 0.0
	if id == REACAO_IRRITADA:
		_reacao_tempo = duracao_irritada
	elif id == REACAO_AGRADECER_AJUDA:
		_reacao_tempo = duracao_agradecer
	else:
		_reacao_tempo = duracao_parada

	var anim := _anim_da_reacao(id)

	# Antes da reação toca a Transição: um meio termo que ESPELHA com a direção e leva à pose de frente
	_reacao_na_transicao = _tem_anim(_nome_anim("Transicao"))
	if _reacao_na_transicao:
		_transicao_tempo = _duracao_animacao(_nome_anim("Transicao"))
		_tocar("Transicao", true)
		_log_reacao("%s iniciada (Transição de %.2f s)" % [id, _transicao_tempo])
	elif _tem_anim(_nome_anim(anim)):
		_tocar(anim, true)
		_log_reacao("%s iniciada (sem Transição)" % id)
	else:
		_log_reacao("%s iniciada (SEM a animação '%s': a pose normal continua)" % [id, _nome_anim(anim)])

	# Avisa uma vez só de cada animação que falta
	for nome in ["Transicao", anim]:
		if not _tem_anim(_nome_anim(nome)) and not _avisou_sem_anim.has(nome):
			_avisou_sem_anim[nome] = true
			push_warning("Player: não existe a animação '%s'." % _nome_anim(nome))

func _encerrar_reacao() -> void:
	_log_reacao("%s encerrada" % reacao_atual)
	reacao_atual = &""
	_reacao_na_transicao = false
	_tempo_ocioso = 0.0

# Irritada e AgradecerAjuda seguram a personagem parada enquanto tocam
func _reacao_trava() -> bool:
	return reacao_atual == REACAO_IRRITADA or reacao_atual == REACAO_AGRADECER_AJUDA

# Espelha o sprite conforme a direção, exceto nas animações que seguem a imagem original
func _aplicar_espelho() -> void:
	if not sprite:
		return
	var nome := String(sprite.animation)
	var sem_espelho := false
	for prefixo in ANIMACOES_SEM_ESPELHO:
		if nome.begins_with(prefixo):
			sem_espelho = true
	sprite.flip_h = olhando_esquerda and not sem_espelho

# Duração (s) de uma passada da animação, somando os quadros e dividindo pela velocidade
func _duracao_animacao(nome: String) -> float:
	var quadros := sprite.sprite_frames
	var fps := quadros.get_animation_speed(nome)
	if fps <= 0.0:
		return 0.0
	var total := 0.0
	for i in quadros.get_frame_count(nome):
		total += quadros.get_frame_duration(nome, i)
	return total / fps

# Nome-base da animação de cada reação (sem Base/Chapeu). A Parada usa a animação "Esperar".
func _anim_da_reacao(id: StringName) -> String:
	if id == REACAO_IRRITADA:
		return "Irritada"
	if id == REACAO_AGRADECER_AJUDA:
		return "Agradecer"
	return "Esperar"

func _log_reacao(texto: String) -> void:
	if imprimir_reacoes:
		print("Reação: ", texto)

# --- BRILHO DA BATIDA DE PÉ (Irritada) ---
# Quando o quadro da batida aparece, solta uma mini explosão de faíscas nos pés (mesmo efeito do Interagivel).
func _ao_mudar_frame() -> void:
	if not brilho_batida_ativo or reacao_atual != REACAO_IRRITADA or not sprite:
		return
	if not String(sprite.animation).begins_with("Irritada"):
		return
	if frame_batida_pe < 0 or sprite.frame == frame_batida_pe:
		_brilho_nos_pes()

func _posicao_pes_global() -> Vector2:
	var local := Vector2.ZERO
	if colisor_corpo != null:
		var capsula := colisor_corpo.shape as CapsuleShape2D
		if capsula != null:
			local = colisor_corpo.position + Vector2(0.0, capsula.height * 0.5 * colisor_corpo.scale.y)
	return to_global(local)

func _brilho_nos_pes() -> void:
	var p := CPUParticles2D.new()
	p.texture = _textura_brilho()
	p.one_shot = true
	p.emitting = false
	p.amount = quantidade_brilho_batida
	p.lifetime = duracao_brilho_batida
	p.explosiveness = 1.0                 # Todas saem de uma vez: efeito de explosão
	p.direction = Vector2.UP
	p.spread = espalhamento_brilho_batida
	p.gravity = Vector2(0, 30)            # Cai bem de leve no final
	p.initial_velocity_min = alcance_brilho_batida * 0.4
	p.initial_velocity_max = alcance_brilho_batida
	p.damping_min = 40.0                  # Freia no ar, como faísca
	p.damping_max = 80.0
	p.scale_amount_min = 0.4 * tamanho_brilho_batida
	p.scale_amount_max = 1.0 * tamanho_brilho_batida
	p.color = cor_brilho_batida

	# Encolhe até sumir
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curva

	# Soma luz em vez de cobrir (fica brilhante de verdade)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat

	# Filho do Player, sem mexer no z_index: fica atrás dos mesmos objetos que ela
	add_child(p)
	var lado := -1.0 if sprite.flip_h else 1.0
	p.global_position = _posicao_pes_global() + Vector2(deslocamento_pe_batida.x * lado, deslocamento_pe_batida.y)
	p.emitting = true
	get_tree().create_timer(duracao_brilho_batida + 0.3).timeout.connect(p.queue_free)

func _textura_brilho() -> Texture2D:
	if _tex_brilho != null:
		return _tex_brilho
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 16
	t.height = 16
	_tex_brilho = t
	return _tex_brilho

# Sensor que detecta as Area2D do cenário (o Player é um corpo e não detecta áreas sozinho)
func _criar_sensor() -> void:
	if colisor_corpo == null or colisor_corpo.shape == null:
		push_warning("Player: sem CollisionShape2D, o sensor de áreas (AreaPrePortal) não foi criado.")
		return
	_sensor = Area2D.new()
	_sensor.name = "SensorAreas"
	_sensor.collision_layer = 0            # Ninguém detecta o sensor
	_sensor.collision_mask = mascara_sensor
	_sensor.monitorable = false
	var forma := CollisionShape2D.new()
	forma.shape = colisor_corpo.shape      # Mesma cápsula do corpo
	forma.position = colisor_corpo.position
	_sensor.add_child(forma)
	add_child(_sensor)
	_sensor.area_entered.connect(_ao_entrar_em_area)

func _ao_entrar_em_area(area: Area2D) -> void:
	if String(area.name).begins_with("AreaPrePortal") or area.is_in_group("AreaPrePortal"):
		if _deve_ficar_irritada(area):
			tocar_reacao(REACAO_IRRITADA)

# Ponto de integração: quando houver catálogo, só deve irritar se faltarem espécies.
func _deve_ficar_irritada(_area: Area2D) -> bool:
	return true

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

	# Reação em andamento (Irritada, AgradecerAjuda, Parada): vale mais que andar/parado
	if reacao_atual != &"":
		var anim_reacao := "Transicao" if _reacao_na_transicao else _anim_da_reacao(reacao_atual)
		if _tem_anim(_nome_anim(anim_reacao)):
			_tocar(anim_reacao)
			return

	if esta_sentada:
		_tocar("Sentar")
	elif absf(velocity.x) > 10.0:
		_tocar("Correr" if esta_correndo else "Andar")
	else:
		_tocar("Parado")

# FERRAMENTAS DE DESENVOLVIMENTO: só funcionam com o modo debug (666) ligado.
#   H = alterna o chapéu (temporário, até o chapéu ser ligado ao jogo) | Z = Irritada | X = AgradecerAjuda
#   T = teletransporta os pés para o mouse (teste da função teletransportar)
func _unhandled_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo or not em_modo_debug():
		return
	match tecla.physical_keycode:
		KEY_H:
			definir_chapeu(not usando_chapeu)
		KEY_Z:
			tocar_reacao(REACAO_IRRITADA)
		KEY_X:
			agradecer_ajuda()
		KEY_T:
			teletransportar(get_global_mouse_position())
