# ===== SCRIPT DO NÓ "PontoOrigem" (filho do Player). NÃO colar no Player.gd =====
extends Node2D

enum EstadoLenco { REPOUSO, ATAQUE_Q, DEFESA_E, GANCHO }
var estado_atual: EstadoLenco = EstadoLenco.REPOUSO

# --- COMPRIMENTOS E ALCANCES INDEPENDENTES ---
@export var comprimento_maximo: float = 100.0  # Comprimento visual no repouso
@export var alcance_ataque: float = 180.0      # Alcance do ataque (Q) esticado
@export var alcance_defesa: float = 160.0      # Alcance da defesa (E)
@export var alcance_gancho: float = 350.0      # Alcance máximo do gancho

@export var pontos_por_fita: int = 9          # 5 nós base + 4 interpolações
@export var velocidade_transicao: float = 14.0
@export var sensibilidade_arrasto_pulo: float = 0.06 # Reatividade do lenço no pulo/queda

# --- CONFIGURAÇÕES DO GANCHO ---
@export var forca_embalo_ar: float = 500.0   # Aceleração horizontal ao balançar com a corda esticada

# --- ORIGEM DAS FITAS POR ANIMAÇÃO ---
# A gola já está no desenho; aqui a ORIGEM DAS FITAS é que acompanha a gola desenhada.
# Quanto a origem desce (+Y) / desloca (X) em cada FRAME da animação,
# em relação à posição normal (y=21 em pé). As chaves são os nomes reais das animações
# (Base e Chapeu).
# sentar: y=32, 39, 48  ->  offsets 11, 18, 27
# Se a lista tiver menos itens que a animação, o último valor é mantido.
# X é espelhado automaticamente quando o sprite está virado (flip_h).
@export var offset_gola_por_animacao: Dictionary = {
	"SentarBase": [Vector2(0, 11), Vector2(0, 18), Vector2(0, 27)],
	"SentarChapeu": [Vector2(0, 11), Vector2(0, 18), Vector2(0, 27)],
	"LevantarBase": [Vector2(0, 27), Vector2(0, 18), Vector2(0, 11)],
	"LevantarChapeu": [Vector2(0, 27), Vector2(0, 18), Vector2(0, 11)],
}
@export var suavidade_offset_gola: float = 20.0 # Maior = acompanha mais rápido

# --- SUAVIDADE DO ATAQUE / DEFESA ---
# Ataque (Q) e defesa (E): UM aperto dispara a ação inteira na direção do mouse e ela volta sozinha
@export var duracao_formacao_ataque: float = 0.22 # Tempo (s) da ponta até a posição final (Q)
@export var tempo_ativo_ataque: float = 0.12      # Tempo (s) com o ataque esticado (causa dano)
@export var duracao_formacao_defesa: float = 0.2  # Tempo (s) da ponta até a posição final (E)
@export var tempo_ativo_defesa: float = 0.3       # Tempo (s) com a defesa levantada
@export var recarga_acao: float = 0.15            # Pausa (s) ao terminar, antes de poder usar de novo
@export var duracao_retorno: float = 0.4    # Tempo (s) para o lenço voltar ao repouso solto
@export var subdivisoes_curva: int = 4      # Arredondamento das curvas (1 = sem arredondar)

# --- INDICADOR DE ALCANCE DO GANCHO ---
# Botão: crie a ação "ControleMostrarAlcance" no Mapa de Entrada (se não existir, usa a tecla Tab).
@export var indicador_alcance_ativo: bool = true
@export var alcance_alternar: bool = false      # false: mostra enquanto segura | true: liga/desliga a cada aperto
@export var duracao_aviso_alcance: float = 1.2  # Segundos visível ao clicar sem ter onde prender
@export var cor_alcance: Color = Color(0.55, 0.85, 1.0)
const ACAO_ALCANCE: String = "ControleMostrarAlcance"

@onready var fita_tras: Line2D = _achar_fita("FitaTras")
@onready var fita_frente: Line2D = _achar_fita("FitaFrente")
@onready var raio_alcance: RayCast2D = $"../RaioAlcance"
@onready var jogador: CharacterBody2D = $".."

# Nós de Colisão
@onready var area_ataque: Area2D = find_child("AreaAtaque", true, false) as Area2D
@onready var area_defesa: Area2D = find_child("AreaDefesa", true, false) as Area2D

@export var textura_ponta: Texture2D
@export var tamanho_ponta: Vector2 = Vector2(24, 24)

# --- IMPULSO E AGARRAR OBJETO (habilidade aprendida na Primavera) ---
# Valores PROVISÓRIOS, ainda não aprovados: ajuste no Inspetor.
@export_group("Impulso e agarrar objeto")
@export var velocidade_impulso: float = 650.0          # Impulso da personagem rumo a um ponto firme (antes fixo no código)
@export var velocidade_impulso_objeto: float = 650.0   # Impulso que lança um objeto leve rumo à personagem
@export var limite_forca_lenco: float = 5.0            # Maior "força necessária" (massa) que o lenço consegue puxar
@export var leves_exigem_habilidade: bool = true       # true: objetos leves só prendem o lenço depois de aprender AgarrarObjeto
@export var soltar_alem_do_alcance: float = 1.3        # Solta o objeto leve se passar de (alcance_gancho x isto)

# --- LENÇO DE FRENTE (Irritada / Agradecer) ---
# De lado, as duas fitas saem do mesmo ponto (cada uma de um lado do pescoço, vistas de perfil).
# Quando ela olha para o jogador, as duas continuam uma de cada lado do pescoço: as origens se afastam
# para os lados e cada fita cai para o seu lado (a de trás é a que atravessa). Ao terminar, voltam juntas à posição normal.
@export_group("Lenço de frente")
@export var animacoes_de_frente: Array[String] = ["Transicao", "Irritada", "Agradecer", "Esperar"]  # Começo do nome das animações em que ela olha para o jogador
@export var duracao_virar_frente: float = 0.35     # Segundos para as pontas irem cada uma para um lado
@export var duracao_voltar_frente: float = 0.5     # Segundos para voltarem à posição normal
@export var angulo_caimento_frente: float = 55.0   # Graus abaixo da horizontal de cada ponta (90 = reta para baixo)
@export var inverter_lados_frente: bool = false    # Troca qual fita vai para qual lado
@export var separacao_pescoco_frente: float = 10.0 # De frente: distância (px) de cada fita até o centro do pescoço
# Origem de CADA fita, somada à origem comum (mesmo formato do offset_gola_por_animacao: um Vector2 por quadro).
# Vazio = as duas saem do mesmo ponto. Exemplo: "IrritadaBase": [Vector2(-12, 0), Vector2(-12, 0)]
@export var offset_fita_tras_por_animacao: Dictionary = {}
@export var offset_fita_frente_por_animacao: Dictionary = {}

@export_group("Calibração (modo debug)")
@export var mostrar_origens_debug: bool = true     # Com o modo debug ligado, desenha as origens das fitas e o quadro atual

var pontos_tras: Array[Vector2] = []
var pontos_frente: Array[Vector2] = []

var tempo_balanco: float = 0.0
var vel_suave: float = 0.0
var vel_y_suave: float = 0.0

var ponto_ancora_gancho: Vector2 = Vector2.ZERO
var distancia_corda: float = 0.0

# Âncora presa a um objeto/plataforma móvel: o ponto acompanha o alvo
var alvo_gancho: Node2D = null
var ancora_local: Vector2 = Vector2.ZERO
var ancora_segue: bool = false
var ancora_leve: bool = false   # true: a âncora é um objeto leve (o impulso o lança até a personagem)

var efeitos: EfeitosLenco = null   # Efeitos especiais do ataque e da defesa (rastro de luz, faíscas, explosão)

# Lido pelo script do jogador: true quando a corda está tensa (balanço)
var corda_esticada: bool = false

# Nós do jogador guardados uma vez só
var sprite_jogador: Node = null
var ponto_gola: Node2D = null

# Acompanhamento da origem (evita "dobra" nos primeiros pontos da fita)
var origem_anterior: Vector2 = Vector2.ZERO
var origem_inicializada: bool = false
var offset_gola_atual: Vector2 = Vector2.ZERO
var offset_tras_atual: Vector2 = Vector2.ZERO    # Origem extra da fita de trás (suavizada)
var offset_frente_atual: Vector2 = Vector2.ZERO  # Origem extra da fita da frente (suavizada)
var frontal: float = 0.0                         # 0 = de lado | 1 = de frente (uma ponta para cada lado)

# Transições de estado (formação do ataque/defesa e retorno ao repouso)
var estado_anterior: EstadoLenco = EstadoLenco.REPOUSO
var tempo_estado: float = 0.0
var tempo_retorno: float = 999.0
var pontos_inicio_tras: Array[Vector2] = []
var pontos_inicio_frente: Array[Vector2] = []

# Ação rápida (Q/E)
var dir_acao: Vector2 = Vector2.RIGHT              # Direção travada no mouse no momento do aperto
var tempo_recarga: float = 0.0
var acao_pendente: EstadoLenco = EstadoLenco.REPOUSO # Aperto guardado por um instante (REPOUSO = nenhum)
var tempo_acao_pendente: float = 0.0

# Indicador de alcance
var origem_alcance: Vector2 = Vector2.ZERO
var tempo_aviso_alcance: float = 0.0
var alcance_visivel: float = 0.0     # 0 a 1 (fade)
var alcance_alternado: bool = false
var pulso_alcance: float = 1.0       # 0 a 1: anel que se expande ao aparecer (1 = parado)
var tempo_visual_alcance: float = 0.0
var mostrando_alcance_antes: bool = false

func _ready() -> void:
	_garantir_acao_alcance()

	pontos_tras.clear()
	pontos_frente.clear()
	pontos_inicio_tras.clear()
	pontos_inicio_frente.clear()
	for i in range(pontos_por_fita):
		pontos_tras.append(global_position)
		pontos_frente.append(global_position)
		pontos_inicio_tras.append(global_position)
		pontos_inicio_frente.append(global_position)

	if jogador:
		sprite_jogador = jogador.find_child("AnimatedSprite2D", true, false)
		if not sprite_jogador:
			sprite_jogador = jogador.find_child("Sprite", true, false)
		ponto_gola = jogador.get_node_or_null("AnimatedSprite2D/PontoGola") as Node2D
		if not ponto_gola:
			ponto_gola = jogador.get_node_or_null("Sprite/PontoGola") as Node2D

	if not fita_tras or not fita_frente:
		push_warning("PontoOrigem: não achei o Line2D 'FitaTras' e/ou 'FitaFrente'. Confira os nomes na cena (devem estar dentro do jogador).")

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

	# Efeitos especiais: usa o nó "EfeitosLenco" da cena, se existir; senão cria um com os valores padrão
	efeitos = get_node_or_null("EfeitosLenco") as EfeitosLenco
	if efeitos == null:
		efeitos = EfeitosLenco.new()
		efeitos.name = "EfeitosLenco"
		add_child(efeitos)
	efeitos.configurar_cor(_cor_do_lenco())

func _physics_process(delta: float) -> void:
	var pos_origem := global_position
	if ponto_gola:
		pos_origem = ponto_gola.global_position
	pos_origem += _calcular_offset_gola(delta)
	_calcular_offsets_fitas(delta)
	_atualizar_frontal(delta)

	# Faz a fita inteira acompanhar o deslocamento da origem (a base nunca fica para trás)
	_acompanhar_origem(pos_origem)
	_atualizar_indicador_alcance(pos_origem, delta)

	var pos_mouse := get_global_mouse_position()

	# --- LEITURA DE ENTRADAS ---
	# Q / E: um aperto dispara a ação inteira (direção travada no mouse) e ela volta sozinha
	if Input.is_action_just_pressed("ControleAtaqueLenco"):
		if _pode_usar(Habilidades.ATAQUE_LENCO):
			_pedir_acao(EstadoLenco.ATAQUE_Q)
	elif Input.is_action_just_pressed("ControleDefesaLenco"):
		if _pode_usar(Habilidades.DEFESA_LENCO):
			_pedir_acao(EstadoLenco.DEFESA_E)
	elif Input.is_action_just_pressed("ControleFixarLenco"):
		_tentar_disparar_gancho(pos_origem, pos_mouse)

	tempo_recarga = maxf(tempo_recarga - delta, 0.0)
	_checar_fim_acao()
	_executar_acao_pendente(pos_origem, pos_mouse, delta)

	if Input.is_action_just_released("ControleFixarLenco") and estado_atual == EstadoLenco.GANCHO:
		estado_atual = EstadoLenco.REPOUSO

	# Detecta troca de estado (guarda a pose atual para a transição suave)
	if estado_atual != estado_anterior:
		_ao_mudar_estado(estado_anterior, estado_atual)
		estado_anterior = estado_atual
	tempo_estado += delta

	# Fora do gancho a corda nunca está esticada
	if estado_atual != EstadoLenco.GANCHO:
		corda_esticada = false

	# --- MÁQUINA DE ESTADOS ---
	match estado_atual:
		EstadoLenco.REPOUSO:
			_atualizar_repouso_firme(pos_origem, delta)
		EstadoLenco.ATAQUE_Q:
			_atualizar_ataque_q(pos_origem, delta)
		EstadoLenco.DEFESA_E:
			_atualizar_defesa_e(pos_origem, delta)
		EstadoLenco.GANCHO:
			_atualizar_gancho_pendulo(pos_origem, delta)

	_atualizar_efeitos(delta)
	_redesenhar_line2d()
	queue_redraw()

# --- UTILITÁRIOS ---

# Offset da gola conforme a animação atual (sentar abaixa a gola, etc.), suavizado
func _calcular_offset_gola(delta: float) -> Vector2:
	var alvo := _offset_do_dicionario(offset_gola_por_animacao)
	offset_gola_atual = offset_gola_atual.lerp(alvo, 1.0 - exp(-suavidade_offset_gola * delta))
	return offset_gola_atual

# Offset-alvo da animação/quadro atual em um dicionário (mesmo formato do offset_gola_por_animacao).
# X é espelhado quando o sprite está virado (flip_h).
func _offset_do_dicionario(dic: Dictionary) -> Vector2:
	var alvo := Vector2.ZERO
	var anim := sprite_jogador as AnimatedSprite2D
	if anim:
		var nome := String(anim.animation)
		if dic.has(nome):
			var dado = dic[nome]
			if dado is Array and not dado.is_empty():
				alvo = dado[clampi(anim.frame, 0, dado.size() - 1)]
			elif dado is Vector2:
				alvo = dado
			if anim.flip_h:
				alvo.x = -alvo.x
	return alvo

# Origem extra de cada fita (só usada no repouso), suavizada como a da gola
func _calcular_offsets_fitas(delta: float) -> void:
	var k := 1.0 - exp(-suavidade_offset_gola * delta)
	offset_tras_atual = offset_tras_atual.lerp(_offset_do_dicionario(offset_fita_tras_por_animacao), k)
	offset_frente_atual = offset_frente_atual.lerp(_offset_do_dicionario(offset_fita_frente_por_animacao), k)

# Quanto o lenço está "de frente" (0 a 1): sobe ao entrar numa animação de frente e desce ao sair
func _atualizar_frontal(delta: float) -> void:
	var alvo := 1.0 if _animacao_de_frente() else 0.0
	var duracao := duracao_virar_frente if alvo > frontal else duracao_voltar_frente
	frontal = move_toward(frontal, alvo, delta / maxf(duracao, 0.01))

# Para onde ela olha. Vem do Player: nas animações de frente o sprite não espelha,
# mas ela continua "olhando" para o lado de antes.
func _olhando_esquerda() -> bool:
	if jogador and "olhando_esquerda" in jogador:
		return jogador.olhando_esquerda
	return sprite_jogador != null and "flip_h" in sprite_jogador and sprite_jogador.flip_h

func _animacao_de_frente() -> bool:
	var anim := sprite_jogador as AnimatedSprite2D
	if anim == null:
		return false
	var nome := String(anim.animation)
	for prefixo in animacoes_de_frente:
		if nome.begins_with(prefixo):
			return true
	return false

# Move os pontos junto com a origem. O lerp depois só ajusta a FORMA da fita,
# então os primeiros pontos não ficam atrasados em relação à base (era isso que dobrava a curva).
func _acompanhar_origem(origem: Vector2) -> void:
	if not origem_inicializada:
		origem_anterior = origem
		origem_inicializada = true
		for i in range(pontos_por_fita):
			pontos_tras[i] = origem
			pontos_frente[i] = origem
			pontos_inicio_tras[i] = origem
			pontos_inicio_frente[i] = origem
		return

	var deslocamento := origem - origem_anterior
	origem_anterior = origem

	for i in range(1, pontos_por_fita):
		var t := float(i) / float(pontos_por_fita - 1)
		var fator := lerpf(1.0, 0.5, t) # a ponta mantém um pouco de inércia
		pontos_tras[i] += deslocamento * fator
		pontos_frente[i] += deslocamento * fator
		pontos_inicio_tras[i] += deslocamento * fator
		pontos_inicio_frente[i] += deslocamento * fator

# Peso de lerp mais rápido na base e mais lento na ponta
func _peso_ponto(t: float, taxa_base: float, taxa_ponta: float, delta: float) -> float:
	return 1.0 - exp(-lerpf(taxa_base, taxa_ponta, t) * delta)

# Movimento do lenço parado / andando / correndo, com a forma do código antigo:
# a fita de trás ondula em seno, a da frente em cosseno com outro comprimento de onda,
# e uma onda secundária empurra as duas em sentidos opostos.
# Retorna (deslocamento da fita de trás, deslocamento da fita da frente).
# A intensidade vem de 'amp' (a atual), então os valores não mudaram.
func _ondas_repouso(t: float, amp: float, fator_ponta: float) -> Vector2:
	var onda_tras := sin(tempo_balanco - (t * 3.0)) * (amp * 0.92 * fator_ponta)
	var onda_frente := cos(tempo_balanco - (t * 2.6)) * (amp * 1.08 * fator_ponta)
	var onda_sec := sin((tempo_balanco * 1.5) - (t * 5.0)) * (amp * 0.23 * fator_ponta)
	return Vector2(onda_tras + onda_sec, -onda_frente - onda_sec)

# --- TRANSIÇÕES E CURVAS SUAVES ---

# Procura o Line2D: primeiro como irmão deste nó, depois em qualquer lugar do jogador,
# depois entre os filhos deste nó e por fim na cena inteira.
func _achar_fita(nome: String) -> Line2D:
	var no := get_node_or_null("../" + nome) as Line2D
	if no:
		return no
	var pai := get_parent()
	if pai:
		no = pai.find_child(nome, true, false) as Line2D
		if no:
			return no
	no = find_child(nome, true, false) as Line2D
	if no:
		return no
	var cena := get_tree().current_scene
	if cena:
		no = cena.find_child(nome, true, false) as Line2D
	return no

func _ao_mudar_estado(anterior: EstadoLenco, novo: EstadoLenco) -> void:
	tempo_estado = 0.0
	# Guarda a pose atual: a formação do ataque/defesa parte dela
	for i in range(pontos_por_fita):
		pontos_inicio_tras[i] = pontos_tras[i]
		pontos_inicio_frente[i] = pontos_frente[i]
	# Saiu do ataque/defesa (por qualquer motivo): desliga as áreas de dano/defesa
	if anterior == EstadoLenco.ATAQUE_Q or anterior == EstadoLenco.DEFESA_E:
		_desativar_colisores()
	# Saiu do gancho: esquece o alvo preso (um objeto solto segue com a velocidade que tinha)
	if novo != EstadoLenco.GANCHO:
		_limpar_ancora()
	# Saiu do ataque/defesa para o repouso: inicia o retorno lento
	if (anterior == EstadoLenco.ATAQUE_Q or anterior == EstadoLenco.DEFESA_E) and novo == EstadoLenco.REPOUSO:
		tempo_retorno = 0.0

# Lê uma lista de pontos como uma curva suave (Catmull-Rom) em vez de linhas retas.
# 'pos' é fracionário: 2.5 = metade do caminho entre o ponto 2 e o 3.
func _amostrar_caminho(offsets: Array[Vector2], pos: float) -> Vector2:
	var ultimo := offsets.size() - 1
	var i1 := clampi(int(floor(pos)), 0, ultimo)
	var i2 := mini(i1 + 1, ultimo)
	var i0 := maxi(i1 - 1, 0)
	var i3 := mini(i2 + 1, ultimo)
	return offsets[i1].cubic_interpolate(offsets[i2], offsets[i0], offsets[i3], pos - float(i1))

# Forma do ataque/defesa: a figura é "desenhada" pela fita. O ponto 8 (ponta) percorre as posições
# finais dos pontos 1, 2, 3... até chegar na sua; o ponto 7 faz o mesmo até a posição dele, e assim
# por diante. Todos percorrem o MESMO caminho (a própria figura), cada um parando na sua posição.
func _aplicar_forma(origem: Vector2, dir: Vector2, alcance: float,
		offsets_verde: Array[Vector2], offsets_vermelho: Array[Vector2], delta: float, duracao: float) -> void:
	# Posição final de cada ponto da figura (índice 0 = origem)
	var final_verde: Array[Vector2] = []
	var final_vermelho: Array[Vector2] = []
	for k in range(pontos_por_fita):
		var tk := float(k) / float(pontos_por_fita - 1)
		var eixo := origem + (dir * (alcance * tk))
		final_verde.append(eixo + _amostrar_caminho(offsets_verde, tk * 4.0))
		final_vermelho.append(eixo + _amostrar_caminho(offsets_vermelho, tk * 4.0))

	var linear := clampf(tempo_estado / maxf(duracao, 0.01), 0.0, 1.0)
	var u := smoothstep(0.0, 1.0, linear) # 0 = tudo na origem, 1 = figura completa
	# No começo, mistura a pose em que o lenço estava para não dar um salto
	var mistura_inicio := 1.0 - smoothstep(0.0, 0.25, linear)

	for i in range(1, pontos_por_fita):
		var t := float(i) / float(pontos_por_fita - 1)

		# O ponto i anda de 0 até i (em "unidades de ponto") sobre o caminho da figura:
		# quando u = 1/8 a ponta está na posição final do ponto 1, em 2/8 na do ponto 2, etc.
		var s_caminho := float(i) * u
		var alvo_verde := _amostrar_caminho(final_verde, s_caminho)
		var alvo_vermelho := _amostrar_caminho(final_vermelho, s_caminho)

		alvo_verde = alvo_verde.lerp(pontos_inicio_frente[i], mistura_inicio)
		alvo_vermelho = alvo_vermelho.lerp(pontos_inicio_tras[i], mistura_inicio)

		# Suavização leve (a ponta segue o caminho de perto)
		var peso_lerp := _peso_ponto(t, 30.0, 45.0, delta)
		pontos_frente[i] = pontos_frente[i].lerp(alvo_verde, peso_lerp)
		pontos_tras[i] = pontos_tras[i].lerp(alvo_vermelho, peso_lerp)

# Arredonda a fita desenhada (spline passando pelos pontos), sem alterar a simulação
func _suavizar_curva(pts: Array[Vector2]) -> PackedVector2Array:
	var saida := PackedVector2Array()
	var n := pts.size()
	var sub := maxi(subdivisoes_curva, 1)
	for i in range(n - 1):
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, n - 1)]
		for s in range(sub):
			saida.append(p1.cubic_interpolate(p2, p0, p3, float(s) / float(sub)))
	saida.append(pts[n - 1])
	return saida

# --- AÇÃO RÁPIDA (Q / E) ---

# Guarda o aperto por um instante: se cair no meio de outra ação ou da recarga, dispara assim que liberar
func _pedir_acao(novo: EstadoLenco) -> void:
	acao_pendente = novo
	tempo_acao_pendente = 0.2

func _executar_acao_pendente(origem: Vector2, alvo_mouse: Vector2, delta: float) -> void:
	if acao_pendente == EstadoLenco.REPOUSO:
		return

	tempo_acao_pendente -= delta
	if tempo_acao_pendente < 0.0:
		acao_pendente = EstadoLenco.REPOUSO
		return

	# Ainda ocupado (outra ação rolando ou em recarga): espera
	if estado_atual == EstadoLenco.ATAQUE_Q or estado_atual == EstadoLenco.DEFESA_E or tempo_recarga > 0.0:
		return

	# Trava a direção do mouse neste instante (sem mouse válido, usa para onde o personagem olha)
	var vetor := alvo_mouse - origem
	if vetor.length() > 1.0:
		dir_acao = vetor.normalized()
	else:
		var olhando_esquerda: bool = _olhando_esquerda()
		dir_acao = Vector2.LEFT if olhando_esquerda else Vector2.RIGHT

	estado_atual = acao_pendente
	acao_pendente = EstadoLenco.REPOUSO

# Termina o ataque/defesa depois da formação + tempo ativo e volta para o repouso
func _checar_fim_acao() -> void:
	var total := 0.0
	match estado_atual:
		EstadoLenco.ATAQUE_Q:
			total = duracao_formacao_ataque + tempo_ativo_ataque
		EstadoLenco.DEFESA_E:
			total = duracao_formacao_defesa + tempo_ativo_defesa
		_:
			return

	if tempo_estado >= total:
		estado_atual = EstadoLenco.REPOUSO
		_desativar_colisores()
		tempo_recarga = recarga_acao

# --- INDICADOR DE ALCANCE ---

# Se a ação "ControleMostrarAlcance" não existir no Mapa de Entrada, cria uma com a tecla Tab
func _garantir_acao_alcance() -> void:
	if InputMap.has_action(ACAO_ALCANCE):
		return
	InputMap.add_action(ACAO_ALCANCE)
	var evento := InputEventKey.new()
	evento.physical_keycode = KEY_TAB
	InputMap.action_add_event(ACAO_ALCANCE, evento)

func _atualizar_indicador_alcance(origem: Vector2, delta: float) -> void:
	origem_alcance = origem

	if not indicador_alcance_ativo:
		alcance_visivel = 0.0
		return

	# Botão (segurar ou alternar)
	var botao := false
	if alcance_alternar:
		if Input.is_action_just_pressed(ACAO_ALCANCE):
			alcance_alternado = not alcance_alternado
		botao = alcance_alternado
	else:
		botao = Input.is_action_pressed(ACAO_ALCANCE)

	# Aviso temporário (clicou sem ter onde prender)
	tempo_aviso_alcance = maxf(tempo_aviso_alcance - delta, 0.0)
	var mostrando := botao or tempo_aviso_alcance > 0.0

	# Ao começar a mostrar, dispara o anel que se expande a partir do personagem
	if mostrando and not mostrando_alcance_antes:
		pulso_alcance = 0.0
	mostrando_alcance_antes = mostrando
	pulso_alcance = minf(pulso_alcance + delta / 0.35, 1.0)

	# Aparece rápido e some devagar
	var alvo := 1.0 if mostrando else 0.0
	alcance_visivel = move_toward(alcance_visivel, alvo, delta * (6.0 if mostrando else 3.0))
	tempo_visual_alcance += delta

# Círculo ao redor do personagem com o raio do alcance do gancho
func _desenhar_alcance() -> void:
	if alcance_visivel <= 0.01:
		return

	var centro := to_local(origem_alcance)
	var raio := alcance_gancho
	var a := alcance_visivel

	# Preenchimento suave
	draw_circle(centro, raio, Color(cor_alcance, 0.07 * a))

	# Anel contínuo fino
	draw_arc(centro, raio, 0.0, TAU, 128, Color(cor_alcance, 0.35 * a), 1.5, true)

	# Anel tracejado girando devagar
	var tracos := 48
	var passo := TAU / float(tracos)
	var giro := tempo_visual_alcance * 0.15
	for k in range(0, tracos, 2):
		var inicio := giro + float(k) * passo
		draw_arc(centro, raio, inicio, inicio + passo * 0.8, 6, Color(cor_alcance, 0.85 * a), 3.0, true)

	# Anel que se expande ao aparecer
	if pulso_alcance < 1.0:
		var e := 1.0 - pow(1.0 - pulso_alcance, 3.0)
		draw_arc(centro, raio * e, 0.0, TAU, 96, Color(cor_alcance, (1.0 - pulso_alcance) * 0.6 * a), 2.5, true)

# --- 1. REPOUSO ESVOAÇANTE (PARADO / CAMINHAR / CORRER + INÉRCIA NO PULO) ---
func _atualizar_repouso_firme(origem: Vector2, delta: float) -> void:

	var dir_costas := 1.0 if _olhando_esquerda() else -1.0

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

	# De frente: cada fita cai para o seu lado do pescoço. A da frente fica no lado em que já estava e a
	# de TRÁS é a que atravessa (por trás do corpo). Com 'frontal' = 0 as duas caem juntas, como sempre foi.
	var f := smoothstep(0.0, 1.0, frontal)
	var lado_tras := -dir_costas
	if inverter_lados_frente:
		lado_tras = -lado_tras
	var ang_frente := deg_to_rad(angulo_caimento_frente)
	var dir_tras := dir_caimento.lerp(Vector2(lado_tras * cos(ang_frente), sin(ang_frente)), f).normalized()
	var dir_frente := dir_caimento.lerp(Vector2(-lado_tras * cos(ang_frente), sin(ang_frente)), f).normalized()
	var perp_tras := Vector2(-dir_tras.y, dir_tras.x)
	var perp_frente := Vector2(-dir_frente.y, dir_frente.x)

	# Origem de cada fita: a mesma de lado; de frente, uma de cada lado do pescoço
	var separacao := Vector2(lado_tras * separacao_pescoco_frente * f, 0.0)
	var origem_tras := origem + offset_tras_atual + separacao
	var origem_frente := origem + offset_frente_atual - separacao
	pontos_tras[0] = origem_tras
	pontos_frente[0] = origem_frente

	# Arrasto vertical suavizado (pulo/queda): sobe -> lenço desce, cai -> lenço sobe
	var vel_y: float = jogador.velocity.y if jogador else 0.0
	vel_y_suave = lerpf(vel_y_suave, vel_y, 1.0 - exp(-7.0 * delta))
	var arrasto_v := clampf(-vel_y_suave * sensibilidade_arrasto_pulo, -45.0, 45.0)

	# Arrasto horizontal: o lenço fica "para trás" do movimento
	var arrasto_h := clampf(-vel_x * 0.05, -30.0, 30.0)

	# Logo após soltar Q/E o lenço volta devagar e vai ganhando agilidade até o normal
	tempo_retorno += delta
	var k_retorno := smoothstep(0.0, 1.0, clampf(tempo_retorno / maxf(duracao_retorno, 0.01), 0.0, 1.0))
	var agilidade := lerpf(0.3, 1.0, k_retorno)

	for i in range(1, pontos_por_fita):
		var t := float(i) / float(pontos_por_fita - 1)
		var dist_segmento := comprimento_maximo * t
		var fator_ponta := pow(t, 1.2)

		# Forma do movimento do código antigo, com a intensidade atual
		var ondas := _ondas_repouso(t, amp_vento, fator_ponta)
		var onda_tras := ondas.x
		var onda_frente := ondas.y

		var offset_inercia := Vector2(arrasto_h * fator_ponta, arrasto_v * fator_ponta)
		var pos_base_tras := origem_tras + (dir_tras * dist_segmento) + offset_inercia
		var pos_base_frente := origem_frente + (dir_frente * dist_segmento) + offset_inercia

		var pos_alvo_tras := pos_base_tras + (perp_tras * onda_tras)
		var pos_alvo_frente := pos_base_frente + (perp_frente * onda_frente)

		# Base firme (30) -> ponta solta: mais frouxa parado (5) e mais ágil ao correr (11), como no código antigo
		var peso_lerp := _peso_ponto(t, 30.0 * agilidade, (5.0 + 6.0 * vel_suave) * agilidade, delta)
		pontos_tras[i] = pontos_tras[i].lerp(pos_alvo_tras, peso_lerp)
		pontos_frente[i] = pontos_frente[i].lerp(pos_alvo_frente, peso_lerp)

# --- 2. ATAQUE Q ---
func _atualizar_ataque_q(origem: Vector2, delta: float) -> void:
	pontos_tras[0] = origem
	pontos_frente[0] = origem

	var dir := dir_acao
	var perp := Vector2(-dir.y, dir.x)

	var abertura_losango_1: float = 15.0
	var abertura_losango_2: float = 10.0

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

	_aplicar_forma(origem, dir, alcance_ataque, offsets_verde, offsets_vermelho, delta, duracao_formacao_ataque)

	if area_ataque:
		area_ataque.monitoring = tempo_estado >= duracao_formacao_ataque * 0.6 # ativa quando a ponta está quase lá
		area_ataque.global_position = origem + (dir * (alcance_ataque * 0.7))
		area_ataque.rotation = dir.angle()

# --- 3. DEFESA E ---
func _atualizar_defesa_e(origem: Vector2, delta: float) -> void:
	pontos_tras[0] = origem
	pontos_frente[0] = origem

	var dir := dir_acao
	var perp := Vector2(-dir.y, dir.x)

	var altura_arco_1: float = 15.0
	var altura_cotovelo: float = 10.0
	var recuo_ponta: float = 40.0

	var offsets_verde: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var offsets_vermelho: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]

	offsets_verde[1] = perp * altura_arco_1
	offsets_vermelho[1] = -perp * altura_arco_1
	offsets_verde[2] = Vector2.ZERO
	offsets_vermelho[2] = Vector2.ZERO
	offsets_verde[3] = -perp * altura_cotovelo
	offsets_vermelho[3] = perp * altura_cotovelo
	offsets_verde[4] = (-perp * (altura_cotovelo + 35.0)) - (dir * recuo_ponta)
	offsets_vermelho[4] = (perp * (altura_cotovelo + 35.0)) - (dir * recuo_ponta)

	_aplicar_forma(origem, dir, alcance_defesa, offsets_verde, offsets_vermelho, delta, duracao_formacao_defesa)

	if area_defesa:
		area_defesa.monitoring = tempo_estado >= duracao_formacao_defesa * 0.3
		area_defesa.global_position = origem + (dir * (alcance_defesa * 0.4))
		area_defesa.rotation = dir.angle()

# --- 4. GANCHO: CORDA COMO LIMITE DE DISTÂNCIA ---
func _tentar_disparar_gancho(origem: Vector2, alvo_mouse: Vector2) -> void:
	if not raio_alcance or not jogador:
		return

	raio_alcance.global_position = origem
	raio_alcance.target_position = raio_alcance.to_local(origem + (alvo_mouse - origem).normalized() * alcance_gancho)
	raio_alcance.force_raycast_update()

	if not raio_alcance.is_colliding():
		# Nada para prender: mostra o círculo de alcance
		tempo_aviso_alcance = duracao_aviso_alcance
		return

	var colisor := raio_alcance.get_collider()
	var ponto := raio_alcance.get_collision_point()

	# Objeto móvel (empurrável pela física): leve ou pesado, conforme o limite de força
	var leve := false
	if colisor is RigidBody2D:
		leve = _forca_necessaria(colisor) <= limite_forca_lenco
		# Um objeto leve só prende o lenço depois de aprender AgarrarObjeto
		if leve and leves_exigem_habilidade and not _pode_usar(Habilidades.AGARRAR_OBJETO):
			tempo_aviso_alcance = duracao_aviso_alcance
			return

	# O mouse esquerdo prende em tudo. O que o impulso (botão direito) faz depende do alvo:
	#   parede, chão ou objeto pesado -> a personagem vai até o ponto
	#   objeto leve                   -> o objeto é lançado até a personagem
	_limpar_ancora()
	ponto_ancora_gancho = ponto
	if colisor is RigidBody2D or colisor is AnimatableBody2D:
		# O ponto acompanha o objeto/plataforma se ele se mover
		alvo_gancho = colisor as Node2D
		ancora_local = alvo_gancho.to_local(ponto)
		ancora_segue = true
	ancora_leve = leve

	var dist := jogador.global_position.distance_to(ponto_ancora_gancho)
	# No chão: corda com todo o alcance (anda e pula livremente).
	# No ar: balança com a distância atual.
	distancia_corda = maxf(alcance_gancho, dist) if jogador.is_on_floor() else dist
	estado_atual = EstadoLenco.GANCHO

func _atualizar_gancho_pendulo(origem: Vector2, delta: float) -> void:
	pontos_tras[0] = origem
	pontos_frente[0] = origem

	# Âncora presa a um objeto/plataforma móvel: o ponto acompanha o alvo
	if ancora_segue:
		if is_instance_valid(alvo_gancho):
			ponto_ancora_gancho = alvo_gancho.to_global(ancora_local)
		else:
			estado_atual = EstadoLenco.REPOUSO
			return

	for i in range(1, pontos_por_fita):
		var t := float(i) / float(pontos_por_fita - 1)
		var pos_linha := origem.lerp(ponto_ancora_gancho, t)
		# Base rápida (45) -> ponta (18): a fita sai reta da gola, sem dobra
		var peso_fita := _peso_ponto(t, 45.0, 18.0, delta)
		pontos_tras[i] = pontos_tras[i].lerp(pos_linha, peso_fita)
		pontos_frente[i] = pontos_frente[i].lerp(pos_linha, peso_fita)

	if not jogador:
		return

	# Objeto leve: o impulso lança o OBJETO até a personagem (a corda não segura nem puxa a personagem)
	if ancora_leve:
		corda_esticada = false
		_atualizar_gancho_leve(origem)
		return

	# BOTÃO DIREITO: impulso da personagem até o ponto firme
	if Input.is_action_pressed("ControleImpulsoLenco"):
		var dir_puxao := (ponto_ancora_gancho - origem).normalized()
		jogador.velocity = dir_puxao * velocidade_impulso
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
		var input_h := Input.get_axis("ControleAndarEsquerda", "ControleAndarDireita")
		if input_h != 0.0:
			var tang := Vector2(-dir_corda.y, dir_corda.x)
			if tang.x * input_h < 0.0:
				tang = -tang
			jogador.velocity += tang * forca_embalo_ar * delta

# --- 5. OBJETO LEVE PRESO AO LENÇO ---
# Enquanto o botão esquerdo segura, a fita acompanha o objeto. O botão direito dá um IMPULSO nele,
# rumo à personagem: ele sai voando com essa velocidade e a física faz o resto (não gruda do nada).
func _atualizar_gancho_leve(origem: Vector2) -> void:
	var objeto := alvo_gancho as RigidBody2D

	# Perdeu o objeto, a permissão (ex.: modo debug desligado) ou ele foi longe demais: solta
	if not is_instance_valid(objeto) \
			or (leves_exigem_habilidade and not _pode_usar(Habilidades.AGARRAR_OBJETO)) \
			or origem.distance_to(objeto.global_position) > alcance_gancho * soltar_alem_do_alcance:
		estado_atual = EstadoLenco.REPOUSO
		return

	if Input.is_action_pressed("ControleImpulsoLenco"):
		var dir := (origem - objeto.global_position).normalized()
		objeto.sleeping = false
		objeto.linear_velocity = dir * velocidade_impulso_objeto
		estado_atual = EstadoLenco.REPOUSO   # O impulso gasta o gancho, como o impulso da personagem

# "Força necessária" para agarrar: o metadado 'forca_necessaria' do objeto (se existir) ou a massa dele
func _forca_necessaria(corpo: Object) -> float:
	if corpo.has_meta("forca_necessaria"):
		return float(corpo.get_meta("forca_necessaria"))
	var rigido := corpo as RigidBody2D
	if rigido != null:
		return rigido.mass
	return INF

# Solta o gancho e cancela qualquer ação do lenço; a fita recomeça junto da gola (usado ao teletransportar)
func soltar_tudo() -> void:
	estado_atual = EstadoLenco.REPOUSO
	acao_pendente = EstadoLenco.REPOUSO
	tempo_acao_pendente = 0.0
	corda_esticada = false
	origem_inicializada = false   # Os pontos da fita voltam a nascer na gola, sem esticar pelo mapa
	if efeitos:
		efeitos.parar()
	_limpar_ancora()
	_desativar_colisores()

func _limpar_ancora() -> void:
	alvo_gancho = null
	ancora_segue = false
	ancora_leve = false

# Pergunta ao Player se a habilidade está liberada (sem Player ou sem o método, libera)
func _pode_usar(id: StringName) -> bool:
	if jogador and jogador.has_method("pode_usar"):
		return jogador.pode_usar(id)
	return true

# Efeitos do ataque e da defesa: o feixe segue as pontas das fitas e explode quando a figura fica completa
func _atualizar_efeitos(delta: float) -> void:
	if efeitos == null:
		return
	var tipo := EfeitosLenco.Tipo.NENHUM
	var progresso := 1.0
	match estado_atual:
		EstadoLenco.ATAQUE_Q:
			tipo = EfeitosLenco.Tipo.ATAQUE
			progresso = clampf(tempo_estado / maxf(duracao_formacao_ataque, 0.01), 0.0, 1.0)
		EstadoLenco.DEFESA_E:
			tipo = EfeitosLenco.Tipo.DEFESA
			progresso = clampf(tempo_estado / maxf(duracao_formacao_defesa, 0.01), 0.0, 1.0)
	efeitos.atualizar(delta, tipo, dir_acao, progresso,
			pontos_tras[pontos_por_fita - 1], pontos_frente[pontos_por_fita - 1])

# Cor das fitas (o fim do degradê), usada de base para os efeitos
func _cor_do_lenco() -> Color:
	if fita_tras:
		var g := fita_tras.gradient
		if g != null and g.get_point_count() > 0:
			return g.get_color(g.get_point_count() - 1)
		return fita_tras.default_color
	return Color(0.125, 0.0, 0.402, 1.0)

func _desativar_colisores() -> void:
	if area_ataque: area_ataque.monitoring = false
	if area_defesa: area_defesa.monitoring = false

func _redesenhar_line2d() -> void:
	if not fita_tras or not fita_frente:
		return

	fita_tras.clear_points()
	fita_frente.clear_points()

	for pt in _suavizar_curva(pontos_tras):
		fita_tras.add_point(fita_tras.to_local(pt))
	for pt in _suavizar_curva(pontos_frente):
		fita_frente.add_point(fita_frente.to_local(pt))

func _draw() -> void:
	_desenhar_alcance()
	_desenhar_origens_debug()

	if not textura_ponta: return

	if pontos_tras.size() >= pontos_por_fita:
		_desenhar_ponta_no_ponto(pontos_tras[pontos_por_fita - 2], pontos_tras[pontos_por_fita - 1])

	if pontos_frente.size() >= pontos_por_fita:
		_desenhar_ponta_no_ponto(pontos_frente[pontos_por_fita - 2], pontos_frente[pontos_por_fita - 1])

# Calibração (só com o modo debug ligado): mostra de onde saem as fitas e o quadro da animação atual.
# Azul = origem comum | rosa = fita de trás | amarelo = fita da frente
func _desenhar_origens_debug() -> void:
	if not mostrar_origens_debug or jogador == null or not jogador.has_method("em_modo_debug"):
		return
	if not jogador.em_modo_debug():
		return
	var centro := to_local(origem_anterior)
	draw_circle(centro, 3.0, Color(0.2, 0.9, 1.0))
	draw_circle(to_local(origem_anterior + offset_tras_atual), 2.0, Color(1.0, 0.3, 0.9))
	draw_circle(to_local(origem_anterior + offset_frente_atual), 2.0, Color(1.0, 0.9, 0.2))
	var anim := sprite_jogador as AnimatedSprite2D
	if anim:
		var texto := "%s  quadro %d  off=(%.0f, %.0f)" % [anim.animation, anim.frame, offset_gola_atual.x, offset_gola_atual.y]
		draw_string(ThemeDB.fallback_font, centro + Vector2(10.0, -6.0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(1, 1, 1))

func _desenhar_ponta_no_ponto(ponto_anterior: Vector2, ponto_final: Vector2) -> void:
	var pos_local := to_local(ponto_final)
	var direcao := (ponto_final - ponto_anterior).normalized()
	var angulo := direcao.angle()

	var rect := Rect2(-tamanho_ponta / 2.0, tamanho_ponta)

	draw_set_transform(pos_local, angulo)
	draw_texture_rect(textura_ponta, rect, false)
	draw_set_transform(Vector2.ZERO, 0.0)
