extends Node2D

enum EstadoLenco { REPOUSO, ATAQUE_Q, DEFESA_E, GANCHO }
var estado_atual: EstadoLenco = EstadoLenco.REPOUSO

# --- COMPRIMENTOS E ALCANCES INDEPENDENTES ---
@export var comprimento_maximo: float = 100.0  # Comprimento visual no repouso
@export var alcance_ataque: float = 280.0      # Alcance do ataque (Q) esticado
@export var alcance_defesa: float = 160.0      # Alcance da defesa (E)
@export var alcance_gancho: float = 350.0      # Alcance máximo do gancho

@export var pontos_por_fita: int = 9          # 5 nós base + 4 interpolações
@export var velocidade_transicao: float = 14.0
@export var sensibilidade_arrasto_pulo: float = 0.06 # Reatividade do lenço no pulo/queda

# --- CONFIGURAÇÕES DO GANCHO ---
@export var forca_embalo_ar: float = 500.0   # Aceleração horizontal ao balançar com a corda esticada

# --- AJUSTE DA GOLA POR ANIMAÇÃO ---
# Quanto o ponto de origem desce (+Y) / desloca (X) em cada FRAME da animação,
# em relação à posição normal do PontoGola (y=21 em pé).
# sentar: y=32, 39, 48  ->  offsets 11, 18, 27
# Se a lista tiver menos itens que a animação, o último valor é mantido.
# X é espelhado automaticamente quando o sprite está virado (flip_h).
@export var offset_gola_por_animacao: Dictionary = {
	"sentar": [Vector2(0, 11), Vector2(0, 18), Vector2(0, 27)],
	"levantar": [Vector2(0, 27), Vector2(0, 18), Vector2(0, 11)],
}
@export var suavidade_offset_gola: float = 20.0 # Maior = acompanha mais rápido

@onready var fita_tras: Line2D = $"../FitaTras"
@onready var fita_frente: Line2D = $"../FitaFrente"
@onready var raio_alcance: RayCast2D = $"../RaioAlcance"
@onready var jogador: CharacterBody2D = $".."

# Nós de Colisão
@onready var area_ataque: Area2D = find_child("AreaAtaque", true, false) as Area2D
@onready var area_defesa: Area2D = find_child("AreaDefesa", true, false) as Area2D

@export var textura_ponta: Texture2D
@export var tamanho_ponta: Vector2 = Vector2(24, 24)

var pontos_tras: Array[Vector2] = []
var pontos_frente: Array[Vector2] = []

var tempo_balanco: float = 0.0
var vel_suave: float = 0.0
var vel_y_suave: float = 0.0

var ponto_ancora_gancho: Vector2 = Vector2.ZERO
var distancia_corda: float = 0.0

# Lido pelo script do jogador: true quando a corda está tensa (balanço)
var corda_esticada: bool = false

# Nós do jogador guardados uma vez só
var sprite_jogador: Node = null
var ponto_gola: Node2D = null

# Acompanhamento da origem (evita "dobra" nos primeiros pontos da fita)
var origem_anterior: Vector2 = Vector2.ZERO
var origem_inicializada: bool = false
var offset_gola_atual: Vector2 = Vector2.ZERO

func _ready() -> void:
	pontos_tras.clear()
	pontos_frente.clear()
	for i in range(pontos_por_fita):
		pontos_tras.append(global_position)
		pontos_frente.append(global_position)

	if jogador:
		sprite_jogador = jogador.find_child("AnimatedSprite2D", true, false)
		if not sprite_jogador:
			sprite_jogador = jogador.find_child("Sprite", true, false)
		ponto_gola = jogador.get_node_or_null("AnimatedSprite2D/PontoGola") as Node2D
		if not ponto_gola:
			ponto_gola = jogador.get_node_or_null("Sprite/PontoGola") as Node2D

	if fita_tras:
		fita_tras.joint_mode = Line2D.LINE_JOINT_ROUND
		fita_tras.begin_cap_mode = Line2D.LINE_CAP_ROUND
		fita_tras.end_cap_mode = Line2D.LINE_CAP_ROUND
	if fita_frente:
		fita_frente.joint_mode = Line2D.LINE_JOINT_ROUND
		fita_frente.begin_cap_mode = Line2D.LINE_CAP_ROUND
		fita_frente.end_cap_mode = Line2D.LINE_CAP_ROUND

	if raio_alcance:
		raio_alcance.target_position = Vector2(alcance_gancho, 0)

	_desativar_colisores()

func _physics_process(delta: float) -> void:
	var pos_origem := global_position
	if ponto_gola:
		pos_origem = ponto_gola.global_position
	pos_origem += _calcular_offset_gola(delta)

	# Faz a fita inteira acompanhar o deslocamento da origem (a base nunca fica para trás)
	_acompanhar_origem(pos_origem)

	var pos_mouse := get_global_mouse_position()

	# --- LEITURA DE ENTRADAS ---
	if Input.is_action_just_pressed("ataque_q"):
		estado_atual = EstadoLenco.ATAQUE_Q
	elif Input.is_action_just_pressed("defesa_e"):
		estado_atual = EstadoLenco.DEFESA_E
	elif Input.is_action_just_pressed("clique_esquerdo"):
		_tentar_disparar_gancho(pos_origem, pos_mouse)

	if Input.is_action_just_released("ataque_q") or Input.is_action_just_released("defesa_e"):
		if estado_atual != EstadoLenco.GANCHO:
			estado_atual = EstadoLenco.REPOUSO
			_desativar_colisores()

	if Input.is_action_just_released("clique_esquerdo") and estado_atual == EstadoLenco.GANCHO:
		estado_atual = EstadoLenco.REPOUSO

	# Fora do gancho a corda nunca está esticada
	if estado_atual != EstadoLenco.GANCHO:
		corda_esticada = false

	# --- MÁQUINA DE ESTADOS ---
	match estado_atual:
		EstadoLenco.REPOUSO:
			_atualizar_repouso_firme(pos_origem, delta)
		EstadoLenco.ATAQUE_Q:
			_atualizar_ataque_q(pos_origem, pos_mouse, delta)
		EstadoLenco.DEFESA_E:
			_atualizar_defesa_e(pos_origem, pos_mouse, delta)
		EstadoLenco.GANCHO:
			_atualizar_gancho_pendulo(pos_origem, delta)

	_redesenhar_line2d()
	queue_redraw()

# --- UTILITÁRIOS ---

# Offset da gola conforme a animação atual (sentar abaixa a gola, etc.), suavizado
func _calcular_offset_gola(delta: float) -> Vector2:
	var alvo := Vector2.ZERO
	var anim := sprite_jogador as AnimatedSprite2D
	if anim:
		var nome := String(anim.animation)
		if offset_gola_por_animacao.has(nome):
			var dado = offset_gola_por_animacao[nome]
			if dado is Array and not dado.is_empty():
				alvo = dado[clampi(anim.frame, 0, dado.size() - 1)]
			elif dado is Vector2:
				alvo = dado
			if anim.flip_h:
				alvo.x = -alvo.x
	offset_gola_atual = offset_gola_atual.lerp(alvo, 1.0 - exp(-suavidade_offset_gola * delta))
	return offset_gola_atual

# Move os pontos junto com a origem. O lerp depois só ajusta a FORMA da fita,
# então os primeiros pontos não ficam atrasados em relação à base (era isso que dobrava a curva).
func _acompanhar_origem(origem: Vector2) -> void:
	if not origem_inicializada:
		origem_anterior = origem
		origem_inicializada = true
		for i in range(pontos_por_fita):
			pontos_tras[i] = origem
			pontos_frente[i] = origem
		return

	var deslocamento := origem - origem_anterior
	origem_anterior = origem

	for i in range(1, pontos_por_fita):
		var t := float(i) / float(pontos_por_fita - 1)
		var fator := lerpf(1.0, 0.5, t) # a ponta mantém um pouco de inércia
		pontos_tras[i] += deslocamento * fator
		pontos_frente[i] += deslocamento * fator

# Peso de lerp mais rápido na base e mais lento na ponta
func _peso_ponto(t: float, taxa_base: float, taxa_ponta: float, delta: float) -> float:
	return 1.0 - exp(-lerpf(taxa_base, taxa_ponta, t) * delta)

# Ondulação de uma fita (primária + secundária + tremulação leve), com fase própria
func _onda_fita(t: float, fase: float, amp: float, fator_ponta: float) -> float:
	var primaria := sin(tempo_balanco - (t * 4.5) + fase) * amp
	var secundaria := cos((tempo_balanco * 1.7) - (t * 6.0) + fase) * (amp * 0.3)
	var micro := sin((tempo_balanco * 3.1) - (t * 8.0) + fase) * (1.5 + 2.5 * vel_suave)
	return (primaria + secundaria + micro) * fator_ponta

# --- 1. REPOUSO ESVOAÇANTE (PARADO / CAMINHAR / CORRER + INÉRCIA NO PULO) ---
func _atualizar_repouso_firme(origem: Vector2, delta: float) -> void:
	pontos_tras[0] = origem
	pontos_frente[0] = origem

	var dir_costas := -1.0
	if sprite_jogador and "flip_h" in sprite_jogador and sprite_jogador.flip_h:
		dir_costas = 1.0

	var vel_x: float = jogador.velocity.x if jogador else 0.0
	var vel_normalizada: float = clampf(absf(vel_x) / 320.0, 0.0, 1.0)
	vel_suave = lerpf(vel_suave, vel_normalizada, 4.0 * delta)

	# Parado mantém o balanço lento; andar e correr são mais contidos
	# (a curva ^1.5 deixa o andar bem suave e o correr só um pouco maior)
	var intensidade := pow(vel_suave, 1.5)
	var freq_vento := lerpf(2.2, 7.5, vel_suave)
	var amp_vento := lerpf(10.0, 19.0, intensidade)
	tempo_balanco += delta * freq_vento

	# Ângulo de caimento: 40° (parado, mais elevado) -> ~15° (andar) -> -10° (correr)
	var angulo_caimento := lerpf(deg_to_rad(40.0), deg_to_rad(-10.0), vel_suave)
	var dir_caimento := Vector2(dir_costas * cos(angulo_caimento), sin(angulo_caimento))
	var perp_caimento := Vector2(-dir_caimento.y, dir_caimento.x)

	# Arrasto vertical suavizado (pulo/queda): sobe -> lenço desce, cai -> lenço sobe
	var vel_y: float = jogador.velocity.y if jogador else 0.0
	vel_y_suave = lerpf(vel_y_suave, vel_y, 1.0 - exp(-7.0 * delta))
	var arrasto_v := clampf(-vel_y_suave * sensibilidade_arrasto_pulo, -45.0, 45.0)

	# Arrasto horizontal: o lenço fica "para trás" do movimento
	var arrasto_h := clampf(-vel_x * 0.05, -30.0, 30.0)

	for i in range(1, pontos_por_fita):
		var t := float(i) / float(pontos_por_fita - 1)
		var dist_segmento := comprimento_maximo * t
		var fator_ponta := pow(t, 1.1)

		# Mesma fórmula nas duas fitas, só com fase diferente: amplitude igual, movimento não idêntico
		var onda_tras := _onda_fita(t, 0.0, amp_vento, fator_ponta)
		var onda_frente := _onda_fita(t, PI * 0.85, amp_vento, fator_ponta)

		var offset_inercia := Vector2(arrasto_h * fator_ponta, arrasto_v * fator_ponta)
		var pos_base := origem + (dir_caimento * dist_segmento) + offset_inercia

		var pos_alvo_tras := pos_base + (perp_caimento * onda_tras)
		var pos_alvo_frente := pos_base + (perp_caimento * onda_frente)

		# Base firme (30) -> ponta solta (7): efeito de atraso do tecido sem dobrar o começo
		var peso_lerp := _peso_ponto(t, 30.0, 7.0, delta)
		pontos_tras[i] = pontos_tras[i].lerp(pos_alvo_tras, peso_lerp)
		pontos_frente[i] = pontos_frente[i].lerp(pos_alvo_frente, peso_lerp)

# --- 2. ATAQUE Q ---
func _atualizar_ataque_q(origem: Vector2, alvo_mouse: Vector2, delta: float) -> void:
	pontos_tras[0] = origem
	pontos_frente[0] = origem

	var dir := (alvo_mouse - origem).normalized()
	var perp := Vector2(-dir.y, dir.x)

	var abertura_losango_1: float = 14.0
	var abertura_losango_2: float = 28.0

	var offsets_verde: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var offsets_vermelho: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]

	offsets_verde[1] = perp * abertura_losango_1
	offsets_vermelho[1] = -perp * abertura_losango_1
	offsets_verde[2] = Vector2.ZERO
	offsets_vermelho[2] = Vector2.ZERO
	offsets_verde[3] = -perp * abertura_losango_2
	offsets_vermelho[3] = perp * abertura_losango_2
	offsets_verde[4] = Vector2.ZERO
	offsets_vermelho[4] = Vector2.ZERO

	var taxa_ponta := velocidade_transicao * 2.5

	for i in range(1, pontos_por_fita):
		var t := float(i) / float(pontos_por_fita - 1)
		var pos_eixo := origem + (dir * (alcance_ataque * t))

		var offset_verde := Vector2.ZERO
		var offset_vermelho := Vector2.ZERO

		if i % 2 == 0:
			var idx_base := int(float(i) * 0.5)
			offset_verde = offsets_verde[idx_base]
			offset_vermelho = offsets_vermelho[idx_base]
		else:
			var idx_ant := int(float(i - 1) * 0.5)
			var idx_prox := int(float(i + 1) * 0.5)
			offset_verde = offsets_verde[idx_ant].lerp(offsets_verde[idx_prox], 0.5)
			offset_vermelho = offsets_vermelho[idx_ant].lerp(offsets_vermelho[idx_prox], 0.5)

		var pos_alvo_verde := pos_eixo + offset_verde
		var pos_alvo_vermelho := pos_eixo + offset_vermelho

		var peso_lerp := _peso_ponto(t, taxa_ponta * 2.0, taxa_ponta, delta)
		pontos_frente[i] = pontos_frente[i].lerp(pos_alvo_verde, peso_lerp)
		pontos_tras[i] = pontos_tras[i].lerp(pos_alvo_vermelho, peso_lerp)

	if area_ataque:
		area_ataque.monitoring = true
		area_ataque.global_position = origem + (dir * (alcance_ataque * 0.7))
		area_ataque.rotation = dir.angle()

# --- 3. DEFESA E ---
func _atualizar_defesa_e(origem: Vector2, alvo_mouse: Vector2, delta: float) -> void:
	pontos_tras[0] = origem
	pontos_frente[0] = origem

	var dir := (alvo_mouse - origem).normalized()
	var perp := Vector2(-dir.y, dir.x)

	var altura_arco_1: float = 18.0
	var altura_cotovelo: float = 32.0
	var recuo_ponta: float = 30.0

	var offsets_verde: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var offsets_vermelho: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]

	offsets_verde[1] = perp * altura_arco_1
	offsets_vermelho[1] = -perp * altura_arco_1
	offsets_verde[2] = Vector2.ZERO
	offsets_vermelho[2] = Vector2.ZERO
	offsets_verde[3] = -perp * altura_cotovelo
	offsets_vermelho[3] = perp * altura_cotovelo
	offsets_verde[4] = (-perp * (altura_cotovelo + 20.0)) - (dir * recuo_ponta)
	offsets_vermelho[4] = (perp * (altura_cotovelo + 20.0)) - (dir * recuo_ponta)

	var taxa_ponta := velocidade_transicao * 2.5

	for i in range(1, pontos_por_fita):
		var t := float(i) / float(pontos_por_fita - 1)
		var pos_eixo := origem + (dir * (alcance_defesa * t))

		var offset_verde := Vector2.ZERO
		var offset_vermelho := Vector2.ZERO

		if i % 2 == 0:
			var idx_base := int(float(i) * 0.5)
			offset_verde = offsets_verde[idx_base]
			offset_vermelho = offsets_vermelho[idx_base]
		else:
			var idx_ant := int(float(i - 1) * 0.5)
			var idx_prox := int(float(i + 1) * 0.5)
			offset_verde = offsets_verde[idx_ant].lerp(offsets_verde[idx_prox], 0.5)
			offset_vermelho = offsets_vermelho[idx_ant].lerp(offsets_vermelho[idx_prox], 0.5)

		var pos_alvo_verde := pos_eixo + offset_verde
		var pos_alvo_vermelho := pos_eixo + offset_vermelho

		var peso_lerp := _peso_ponto(t, taxa_ponta * 2.0, taxa_ponta, delta)
		pontos_frente[i] = pontos_frente[i].lerp(pos_alvo_verde, peso_lerp)
		pontos_tras[i] = pontos_tras[i].lerp(pos_alvo_vermelho, peso_lerp)

	if area_defesa:
		area_defesa.monitoring = true
		area_defesa.global_position = origem + (dir * (alcance_defesa * 0.4))
		area_defesa.rotation = dir.angle()

# --- 4. GANCHO: CORDA COMO LIMITE DE DISTÂNCIA ---
func _tentar_disparar_gancho(origem: Vector2, alvo_mouse: Vector2) -> void:
	if not raio_alcance or not jogador:
		return

	raio_alcance.global_position = origem
	raio_alcance.target_position = raio_alcance.to_local(origem + (alvo_mouse - origem).normalized() * alcance_gancho)
	raio_alcance.force_raycast_update()

	if raio_alcance.is_colliding():
		ponto_ancora_gancho = raio_alcance.get_collision_point()
		var dist := jogador.global_position.distance_to(ponto_ancora_gancho)
		# No chão: corda com todo o alcance (anda e pula livremente).
		# No ar: balança com a distância atual.
		distancia_corda = maxf(alcance_gancho, dist) if jogador.is_on_floor() else dist
		estado_atual = EstadoLenco.GANCHO

func _atualizar_gancho_pendulo(origem: Vector2, delta: float) -> void:
	pontos_tras[0] = origem
	pontos_frente[0] = origem

	for i in range(1, pontos_por_fita):
		var t := float(i) / float(pontos_por_fita - 1)
		var pos_linha := origem.lerp(ponto_ancora_gancho, t)
		# Base rápida (45) -> ponta (18): a fita sai reta da gola, sem dobra
		var peso_fita := _peso_ponto(t, 45.0, 18.0, delta)
		pontos_tras[i] = pontos_tras[i].lerp(pos_linha, peso_fita)
		pontos_frente[i] = pontos_frente[i].lerp(pos_linha, peso_fita)

	if not jogador:
		return

	# BOTÃO DIREITO: impulso
	if Input.is_action_pressed("clique_direito"):
		var dir_puxao := (ponto_ancora_gancho - origem).normalized()
		jogador.velocity = dir_puxao * 650.0
		corda_esticada = false
		estado_atual = EstadoLenco.REPOUSO
		return

	# Ao pousar, a corda volta a ter o alcance completo
	if jogador.is_on_floor():
		distancia_corda = maxf(distancia_corda, alcance_gancho)

	var vetor := jogador.global_position - ponto_ancora_gancho
	var dist := vetor.length()

	# Corda frouxa: não interfere, o personagem anda e pula normalmente
	if dist <= distancia_corda or dist < 0.001:
		corda_esticada = false
		return

	corda_esticada = true

	# Corda esticada: devolve o personagem ao círculo e remove a velocidade que o afasta
	var dir_corda := vetor / dist
	var pos_alvo := ponto_ancora_gancho + dir_corda * distancia_corda
	jogador.move_and_collide(pos_alvo - jogador.global_position)

	var v_radial := jogador.velocity.dot(dir_corda)
	if v_radial > 0.0:
		jogador.velocity -= dir_corda * v_radial

	# Embalo no ar usando as setas/A-D
	if not jogador.is_on_floor():
		var input_h := Input.get_axis("mover_esquerda", "mover_direita")
		if input_h != 0.0:
			var tang := Vector2(-dir_corda.y, dir_corda.x)
			if tang.x * input_h < 0.0:
				tang = -tang
			jogador.velocity += tang * forca_embalo_ar * delta

func _desativar_colisores() -> void:
	if area_ataque: area_ataque.monitoring = false
	if area_defesa: area_defesa.monitoring = false

func _redesenhar_line2d() -> void:
	fita_tras.clear_points()
	fita_frente.clear_points()

	for pt in pontos_tras:
		fita_tras.add_point(fita_tras.to_local(pt))
	for pt in pontos_frente:
		fita_frente.add_point(fita_frente.to_local(pt))

func _draw() -> void:
	if not textura_ponta: return

	if pontos_tras.size() >= pontos_por_fita:
		_desenhar_ponta_no_ponto(pontos_tras[pontos_por_fita - 2], pontos_tras[pontos_por_fita - 1])

	if pontos_frente.size() >= pontos_por_fita:
		_desenhar_ponta_no_ponto(pontos_frente[pontos_por_fita - 2], pontos_frente[pontos_por_fita - 1])

func _desenhar_ponta_no_ponto(ponto_anterior: Vector2, ponto_final: Vector2) -> void:
	var pos_local := to_local(ponto_final)
	var direcao := (ponto_final - ponto_anterior).normalized()
	var angulo := direcao.angle()

	var rect := Rect2(-tamanho_ponta / 2.0, tamanho_ponta)

	draw_set_transform(pos_local, angulo)
	draw_texture_rect(textura_ponta, rect, false)
	draw_set_transform(Vector2.ZERO, 0.0)
