extends Node2D

enum EstadoLenco { REPOUSO, ATAQUE_Q, DEFESA_E, GANCHO }
var estado_atual: EstadoLenco = EstadoLenco.REPOUSO

@export var comprimento_maximo: float = 120.0
@export var pontos_por_fita: int = 8
@export var velocidade_transicao: float = 14.0
@export var alcance_gancho: float = 350.0

@onready var fita_tras: Line2D = $"../FitaTras"
@onready var fita_frente: Line2D = $"../FitaFrente"
@onready var raio_alcance: RayCast2D = $"../RaioAlcance"
@onready var jogador: CharacterBody2D = $".."

# Nós de Colisão para Dano e Defesa
@onready var area_ataque: Area2D = find_child("AreaAtaque", true, false) as Area2D
@onready var area_defesa: Area2D = find_child("AreaDefesa", true, false) as Area2D

@export var textura_ponta: Texture2D # Arraste a imagem PNG da ponta no Inspector
@export var tamanho_ponta: Vector2 = Vector2(24, 24) # Ajuste o tamanho visual da lança

var pontos_tras: Array[Vector2] = []
var pontos_frente: Array[Vector2] = []

var tempo_balanco: float = 0.0
var ponto_ancora_gancho: Vector2 = Vector2.ZERO
var distancia_corda: float = 0.0

func _ready() -> void:
	for i in range(pontos_por_fita):
		pontos_tras.append(global_position)
		pontos_frente.append(global_position)
		
	_desativar_colisores()

func _process(delta: float) -> void:
	tempo_balanco += delta * 1.0
	var pos_origem := global_position
	var pos_mouse := get_global_mouse_position()
	
	# --- LEITURA DE ENTRADAS ---
	if Input.is_action_just_pressed("ataque_q"):
		estado_atual = EstadoLenco.ATAQUE_Q
	elif Input.is_action_just_pressed("defesa_e"):
		estado_atual = EstadoLenco.DEFESA_E
	elif Input.is_action_just_pressed("clique_esquerdo"): # Mapeie MOUSE_BUTTON_LEFT
		_tentar_disparar_gancho(pos_origem, pos_mouse)
	
	# Soltar Teclas / Desativar
	if Input.is_action_just_released("ataque_q") or Input.is_action_just_released("defesa_e"):
		if estado_atual != EstadoLenco.GANCHO:
			estado_atual = EstadoLenco.REPOUSO
			_desativar_colisores()
			
	if Input.is_action_just_released("clique_esquerdo") and estado_atual == EstadoLenco.GANCHO:
		estado_atual = EstadoLenco.REPOUSO

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
	queue_redraw() # Pede ao Godot para redesenhar o nó (chama o _draw abaixo)

# --- 1. REPOUSO / FLUTUAÇÃO DE SEDA MÁGICA (8 PONTOS) ---
func _atualizar_repouso_firme(origem: Vector2, delta: float) -> void:
	pontos_tras[0] = origem
	pontos_frente[0] = origem
	
	var dir_costas := -1.0
	if jogador and jogador.has_node("Sprite"):
		var sprite_node = jogador.get_node("Sprite")
		if "flip_h" in sprite_node and sprite_node.flip_h:
			dir_costas = 1.0

	var vel_abs_x: float = abs(jogador.velocity.x) if jogador else 0.0
	var vel_normalizada: float = clampf(vel_abs_x / 320.0, 0.0, 1.0)

	# Frequência suave do vento constante
	var velocidade_vento := 2.5 + (vel_normalizada * 4.0)
	tempo_balanco += delta * velocidade_vento

	# Calculamos segmento a segmento dos 8 pontos (índices 1 a 7)
	for i in range(1, pontos_por_fita):
		var t := float(i) / (pontos_por_fita - 1) # De 0.14 até 1.0 no ponto 7
		
		# O comprimento estica delicadamente ao caminhar/correr
		var dist_segmento := (comprimento_maximo * (0.8 + vel_normalizada * 0.4)) * t
		
		# PROPAGAÇÃO DE ONDA DISSIPADA:
		var fator_ponta := pow(t, 1.2)
		
		var onda_tras := sin(tempo_balanco - (t * 3.0)) * (24.0 * fator_ponta)
		var onda_frente := cos(tempo_balanco - (t * 2.6)) * (28.0 * fator_ponta)
		
		# Leve curvatura secundária em 'S' para suavizar nós intermediários
		var onda_secundaria := sin((tempo_balanco * 1.5) - (t * 5.0)) * (6.0 * fator_ponta)
		
		# Projeção quase horizontal flutuante no ar para trás do personagem
		var pos_alvo_tras := origem + Vector2(
			dir_costas * dist_segmento * 0.9,
			(onda_tras + onda_secundaria) - (10.0 * t * vel_normalizada)
		)
		
		var pos_alvo_frente := origem + Vector2(
			dir_costas * dist_segmento * 1.05, # A fita da frente se estende um pouco mais
			(-onda_frente - onda_secundaria) - (5.0 * t * vel_normalizada)
		)
		
		# LERP DIFERENCIADO POR PONTO
		var suavidade_ponto := lerpf(12.0, 5.0, t) + (vel_normalizada * 6.0)
		
		pontos_tras[i] = pontos_tras[i].lerp(pos_alvo_tras, suavidade_ponto * delta)
		pontos_frente[i] = pontos_frente[i].lerp(pos_alvo_frente, suavidade_ponto * delta)

# --- 2. ATAQUE Q COM COLISÃO ---
func _atualizar_ataque_q(origem: Vector2, alvo_mouse: Vector2, delta: float) -> void:
	pontos_tras[0] = origem
	pontos_frente[0] = origem
	
	var dir := (alvo_mouse - origem).normalized()
	var alcance := origem + (dir * (comprimento_maximo * 1.6))
	
	for i in range(1, pontos_por_fita):
		var t := float(i) / (pontos_por_fita - 1)
		var pos_linha := origem.lerp(alcance, t)
		var offset := Vector2(-dir.y, dir.x) * sin(t * PI * 2.0) * (10.0 * (1.0 - t))
		
		pontos_tras[i] = pontos_tras[i].lerp(pos_linha + offset, velocidade_transicao * 2.5 * delta)
		pontos_frente[i] = pontos_frente[i].lerp(pos_linha - offset, velocidade_transicao * 2.5 * delta)

	# Ativa e posiciona o colisor do ataque na direção da lança
	if area_ataque:
		area_ataque.monitoring = true
		area_ataque.global_position = origem + (dir * (comprimento_maximo * 0.8))
		area_ataque.rotation = dir.angle()

# --- 3. DEFESA E (FORMATO DE "X" ENCRUZILHADO) ---
func _atualizar_defesa_e(origem: Vector2, alvo_mouse: Vector2, delta: float) -> void:
	pontos_tras[0] = origem
	pontos_frente[0] = origem
	
	# Vetor de direção apontando para o cursor do mouse
	var dir := (alvo_mouse - origem).normalized()
	# Vetor perpendicular (perpendicular à direção do mouse para abrir o X)
	var perpendicular := Vector2(-dir.y, dir.x)
	
	# Distância do centro do escudo em relação à personagem
	var pos_centro_escudo := origem + (dir * 45.0)
	
	# Largura da abertura do "X" (altura do escudo)
	var abertura_x: float = 35.0

	for i in range(1, pontos_por_fita):
		var t := float(i) / (pontos_por_fita - 1) # De 0.0 até 1.0 no ponto 7
		
		# Posição ao longo da linha central em direção ao mouse
		var pos_no_eixo := origem.lerp(pos_centro_escudo, t)
		
		var fator_cruzado := (t - 0.5) * 2.0 # Varia de -1.0 até 1.0
		var curvatura := sin(t * PI) * 10.0
		
		# Offset da Fita de Trás
		var offset_tras := (perpendicular * fator_cruzado * abertura_x) + (dir * curvatura)
		
		# Offset da Fita da Frente
		var offset_frente := (-perpendicular * fator_cruzado * abertura_x) + (dir * curvatura)
		
		pontos_tras[i] = pontos_tras[i].lerp(pos_no_eixo + offset_tras, velocidade_transicao * 2.5 * delta)
		pontos_frente[i] = pontos_frente[i].lerp(pos_no_eixo + offset_frente, velocidade_transicao * 2.5 * delta)

	# Atualiza o colisor para cobrir a área do X
	if area_defesa:
		area_defesa.monitoring = true
		area_defesa.global_position = pos_centro_escudo
		area_defesa.rotation = dir.angle()

# --- 4. GANCHO CORRIGIDO (PAREDES LATERAIS + PUXÃO DIRETO) ---

func _tentar_disparar_gancho(origem: Vector2, alvo_mouse: Vector2) -> void:
	if not raio_alcance:
		return

	# Aponta o RayCast2D diretamente para o cursor do mouse
	raio_alcance.global_position = origem
	raio_alcance.target_position = raio_alcance.to_local(origem + (alvo_mouse - origem).normalized() * alcance_gancho)
	raio_alcance.force_raycast_update()

	if raio_alcance.is_colliding():
		ponto_ancora_gancho = raio_alcance.get_collision_point()
		distancia_corda = origem.distance_to(ponto_ancora_gancho)
		estado_atual = EstadoLenco.GANCHO
		
		# Anula o impulso residual/inércia para evitar o tranco para trás
		if jogador:
			jogador.velocity = Vector2.ZERO

func _atualizar_gancho_pendulo(origem: Vector2, delta: float) -> void:
	pontos_tras[0] = origem
	pontos_frente[0] = origem
	
	for i in range(1, pontos_por_fita):
		var t := float(i) / (pontos_por_fita - 1)
		var pos_linha := origem.lerp(ponto_ancora_gancho, t)
		pontos_tras[i] = pontos_tras[i].lerp(pos_linha, velocidade_transicao * 3.0 * delta)
		pontos_frente[i] = pontos_frente[i].lerp(pos_linha, velocidade_transicao * 3.0 * delta)
		
	if not jogador:
		return

	var vetor_para_ancora := ponto_ancora_gancho - origem
	var dist_atual := vetor_para_ancora.length()
	var dir_ancora := vetor_para_ancora.normalized()

	# PUXÃO DIRETO (Mouse Direito)
	if Input.is_action_pressed("clique_direito"):
		jogador.velocity = dir_ancora * 550.0
		return

	# CORDA / GANCHO (Mouse Esquerdo)
	if dist_atual >= distancia_corda:
		var direcao_fita := -dir_ancora
		
		if jogador.is_on_floor():
			# NO CHÃO: Impede apenas que ela ande para ALÉM do raio da fita
			if jogador.velocity.dot(direcao_fita) > 0:
				jogador.velocity.x = 0
		else:
			# NO AR: Física de pêndulo completa
			if jogador.velocity.dot(direcao_fita) > 0:
				jogador.velocity = jogador.velocity.slide(direcao_fita)
			
			jogador.global_position = ponto_ancora_gancho + (direcao_fita * distancia_corda)
			jogador.velocity.x = move_toward(jogador.velocity.x, 0.0, 30.0 * delta)

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

# Função nativa para desenhar a ponta no 8º ponto (índice 7)
func _draw() -> void:
	if not textura_ponta:
		return
		
	if pontos_tras.size() >= 8:
		_desenhar_ponta_no_ponto(pontos_tras[6], pontos_tras[7])

	if pontos_frente.size() >= 8:
		_desenhar_ponta_no_ponto(pontos_frente[6], pontos_frente[7])

func _desenhar_ponta_no_ponto(ponto_anterior: Vector2, ponto_final: Vector2) -> void:
	# Converte a posição global do ponto 7 para a posição local do PontoOrigem
	var pos_local := to_local(ponto_final)
	
	# Calcula para onde a ponta deve estar virada (ângulo entre o ponto 6 e 7)
	var direcao := (ponto_final - ponto_anterior).normalized()
	var angulo := direcao.angle()
	
	# Define o retângulo/tamanho de desenho centralizado
	var rect := Rect2(-tamanho_ponta / 2.0, tamanho_ponta)
	
	# Aplica a transformação (posição e rotação) e desenha a textura
	draw_set_transform(pos_local, angulo)
	draw_texture_rect(textura_ponta, rect, false)
	draw_set_transform(Vector2.ZERO, 0.0)
