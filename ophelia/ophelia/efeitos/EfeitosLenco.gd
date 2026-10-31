class_name OpheliaEfeitosLenco
extends Node2D
## Única instância em Lenco/Efeitos. O controlador fornece estado, cor e percursos.
## A camada traseira já existe na cena como Visual/EfeitosTras.

enum Tipo { NENHUM, ATAQUE, DEFESA, PROPULSOR }

@export_group("Cor")
@export var usar_cor_do_lenco: bool = true               # true: usa a cor das fitas, clareada para brilhar
@export var cor_manual: Color = Color("242542")   # Usada quando 'usar_cor_do_lenco' está desmarcado
@export_range(0.0, 1.0) var saturacao_minima: float = 0.4

@export_group("Rastro (feixe de luz)")
@export var rastro_ativo: bool = true                    # Ataque e propulsor (a defesa tem a luz própria, na redoma)
@export var pontos_do_rastro: int = 18                   # Comprimento do feixe
@export var largura_do_rastro: float = 9.0
@export var recolher_rastro: float = 70.0                # Pontos apagados por segundo depois do auge (velocidade de sumir)

@export_group("Faíscas do feixe")
@export var faiscas_ativas: bool = true
@export var faiscas_por_segundo: float = 70.0
@export var vida_faisca: float = 0.45
@export var tamanho_faisca: float = 0.7

@export_group("Ataque: espiral de luz")
@export var espiral_ataque_ativa: bool = false           # Desligada: girava em volta do golpe (guardada para reaproveitar)
@export var fitas_espiral_ataque: int = 3                # Quantas fitas de luz se enrolam
@export var raio_espiral_ataque: float = 26.0            # Quanto a espiral abre no meio do caminho
@export var voltas_espiral_ataque: float = 2.5
@export var giro_espiral_ataque: float = 16.0            # Velocidade do giro (rad/s)
@export var largura_espiral_ataque: float = 5.0

@export_group("Ataque: explosão no auge")
@export var explosao_ativa: bool = true
@export var quantidade_explosao: int = 26
@export var velocidade_explosao: float = 240.0
@export var vida_explosao: float = 0.6
@export var tamanho_explosao: float = 0.9
@export var raio_onda_ataque: float = 60.0
@export var duracao_onda: float = 0.38

@export_group("Propulsor: jato")
@export var jato_ativo: bool = true
@export var faiscas_do_jato: float = 90.0                # Faíscas por segundo saindo das pontas
@export var velocidade_jato: float = 260.0
@export var vida_jato: float = 0.35
@export var abertura_jato: float = 22.0                  # Abertura do cone do jato (graus)
@export var tamanho_jato: float = 0.9
@export var quantidade_estouro_jato: int = 22            # Faíscas do estouro no instante em que o propulsor dispara

@export_group("Defesa: redoma")
@export var redoma_ativa: bool = true
@export var largura_luz_redoma: float = 5.0              # Largura da luz que corre por cima das fitas
@export var tamanho_cabeca_redoma: float = 15.0          # Raio do brilho que anda na ponta enquanto desenha
@export var faiscas_ponta_redoma: float = 150.0          # Faíscas por segundo saindo das pontas enquanto desenham
@export var vida_faisca_redoma: float = 0.5
@export_range(0.0, 1.0) var opacidade_redoma: float = 0.10   # Miolo suave dentro da redoma fechada
@export var brilhos_na_redoma: float = 26.0              # Faíscas por segundo flutuando na borda depois de fechar
@export var quantidade_estouro_redoma: int = 30          # Faíscas que se soltam da borda no instante em que fecha
@export var quantidade_ecos: int = 2                     # Quantas ondas de eco saem ao fechar
@export var duracao_eco: float = 0.45
@export var expansao_eco: float = 0.35                   # Quanto o eco cresce (0.35 = 35% maior que a redoma)
@export var duracao_sumir_redoma: float = 0.3

# O ControladorLenco avisa quando o ataque atual é o lançamento da ponta (no auge sai só um cone de faíscas, sem anel)
var ataque_a_distancia: bool = false

var _tipo: int = Tipo.NENHUM
var _apice_feito: bool = false
var _cor: Color = Color("7073adff")
var _dir: Vector2 = Vector2.RIGHT
var _acumulo: float = 0.0
var _t: float = 0.0
var _tex: Texture2D = null
var _mat: CanvasItemMaterial = null
@onready var _camada_tras: Node2D = %EfeitosTras     # Atrás do corpo: fundo da redoma e a luz da fita de trás

var _halos: Array[Line2D] = []      # Feixe largo e suave (um por fita)
var _nucleos: Array[Line2D] = []    # Miolo fino e claro do feixe
var _faiscas: Array[CPUParticles2D] = []
var _faiscas_redoma: Array[CPUParticles2D] = []   # Faíscas das pontas enquanto desenham a redoma
var _faiscas_borda: CPUParticles2D = null         # Faíscas flutuando na borda da redoma fechada
var _jato: CPUParticles2D = null
var _hist: Array = [[], []]         # Posições recentes (no mundo) de cada ponta
var _ondas: Array = []              # Anéis em expansão (ataque e propulsor)
var _segs: Array = []               # Segmentos de luz da espiral do ataque (no mundo), refeitos todo quadro
var _havia_desenho: bool = false

# Espiral do ataque
var _a_espiral: float = 0.0
var _giro_ataque: float = 0.0
var _esp_origem: Vector2 = Vector2.ZERO
var _esp_dir: Vector2 = Vector2.RIGHT
var _esp_comp: float = 60.0

# Redoma da defesa (tudo guardado RELATIVO ao centro do corpo, para acompanhar a personagem)
var _def_centro: Vector2 = Vector2.ZERO
var _contorno_rel: PackedVector2Array = PackedVector2Array()   # Borda da redoma, arredondada e fechada
var _centroide_rel: Vector2 = Vector2.ZERO
var _fita_a_rel: PackedVector2Array = PackedVector2Array()     # Fita da frente (luz na camada da frente)
var _fita_b_rel: PackedVector2Array = PackedVector2Array()     # Fita de trás (luz na camada de trás)
var _a_redoma: float = 0.0          # Intensidade geral (0 a 1)
var _fase_fechada: float = 0.0      # 0 = ainda desenhando | 1 = fechada
var _redoma_viva: bool = false      # Fechou e a defesa ainda dura
var _redoma_saindo: bool = false
var _redoma_t: float = 0.0
var _ecos: Array = []               # Ondas de eco (a forma da redoma crescendo)

func _ready() -> void:
	_mat = OpheliaEfeitosComuns.material_aditivo()
	# Material compartilhado   # Soma luz em vez de cobrir
	material = _mat
	_tex = _criar_textura()

	for i in 2:
		_halos.append(_nova_linha(largura_do_rastro))
		_nucleos.append(_nova_linha(largura_do_rastro * 0.35))
		var emissor := _novo_emissor()
		add_child(emissor)
		_faiscas.append(emissor)
		var emissor_redoma := _novo_emissor_ponta_redoma()
		add_child(emissor_redoma)
		_faiscas_redoma.append(emissor_redoma)
	_faiscas_borda = _novo_emissor_borda()
	add_child(_faiscas_borda)
	_jato = _novo_emissor_jato()
	add_child(_jato)
	_aplicar_cor()

	_camada_tras.material = _mat
	_camada_tras.draw.connect(_desenhar_tras)



func configurar_cor(cor_lenco: Color) -> void:
	if usar_cor_do_lenco:
		var sat := clampf(maxf(cor_lenco.s * 1.2, saturacao_minima), 0.0, 0.85)
		_cor = Color.from_hsv(cor_lenco.h, sat, 1.0)
	else:
		_cor = cor_manual
	_aplicar_cor()

# Chamado todo quadro DURANTE a defesa, antes de 'atualizar'. Recebe os cantos da redoma e os pontos das duas
# fitas (no mundo) e o centro do corpo. Tudo é guardado relativo ao centro, para a luz acompanhar a personagem.
func definir_redoma(vertices: Array[Vector2], fita_frente: Array[Vector2], fita_tras: Array[Vector2], centro: Vector2) -> void:
	var cantos := PackedVector2Array()
	var soma := Vector2.ZERO
	for p in vertices:
		cantos.append(p - centro)
		soma += p - centro
	_centroide_rel = soma / float(maxi(vertices.size(), 1))
	_contorno_rel = _contorno_fechado(cantos, 4)
	_fita_a_rel = PackedVector2Array()
	for p in fita_frente:
		_fita_a_rel.append(p - centro)
	_fita_b_rel = PackedVector2Array()
	for p in fita_tras:
		_fita_b_rel.append(p - centro)

# Chamado todo quadro. 'progresso' vai de 0 a 1 enquanto a figura se forma; em 1 é o auge.
func atualizar(delta: float, tipo: int, direcao: Vector2, progresso: float, origem: Vector2,
		ponta_a: Vector2, ponta_b: Vector2, centro_corpo: Vector2) -> void:
	_t += delta
	_giro_ataque += giro_espiral_ataque * delta
	_def_centro = centro_corpo
	var mudou := tipo != _tipo
	if mudou:
		_ao_mudar_tipo(tipo)

	var formando := _tipo != Tipo.NENHUM and progresso < 1.0
	var defesa := _tipo == Tipo.DEFESA
	if _tipo != Tipo.NENHUM:
		_dir = direcao

	# Feixe: grava o caminho das pontas durante o movimento rápido; depois do auge ele vai sumindo
	# (a defesa não usa o feixe: ela tem a luz própria sobre as fitas)
	if formando and not defesa:
		_registrar(0, ponta_a)
		_registrar(1, ponta_b)
	else:
		_recolher(delta)

	# Faíscas acompanham as pontas enquanto a figura se forma
	_faiscas[0].global_position = ponta_a
	_faiscas[1].global_position = ponta_b
	# No propulsor, começa depois de as pontas saírem da gola.
	var emitir_pontas := faiscas_ativas and formando and not defesa
	if _tipo == Tipo.PROPULSOR:
		emitir_pontas = emitir_pontas and progresso >= 0.35
	_faiscas[0].emitting = emitir_pontas
	_faiscas[1].emitting = emitir_pontas

	# Defesa: faíscas mais densas andando junto com as pontas até a redoma fechar
	_faiscas_redoma[0].global_position = ponta_a
	_faiscas_redoma[1].global_position = ponta_b
	_faiscas_redoma[0].emitting = redoma_ativa and defesa and formando
	_faiscas_redoma[1].emitting = redoma_ativa and defesa and formando

	# Propulsor: um jato de faíscas sai das pontas, para o lado apontado, enquanto durar
	_jato.global_position = ponta_a.lerp(ponta_b, 0.5)
	_jato.direction = _dir
	_jato.emitting = jato_ativo and _tipo == Tipo.PROPULSOR and progresso >= 1.0   # Só a partir do auge, junto com o impulso

	if _tipo == Tipo.ATAQUE:
		var meio := ponta_a.lerp(ponta_b, 0.5)
		var v := meio - origem
		_esp_origem = origem
		_esp_comp = maxf(v.length(), 12.0)
		_esp_dir = v.normalized() if v.length() > 4.0 else _dir

	# Auge: a explosão (ataque) ou o fechamento da redoma (defesa) acontece uma vez
	if _tipo != Tipo.NENHUM and progresso >= 1.0 and not _apice_feito:
		_apice_feito = true
		_no_auge(origem, ponta_a, ponta_b)

	_atualizar_luz(delta)
	_atualizar_redoma(delta)
	_atualizar_linhas()
	_atualizar_desenho(delta)

# Apaga tudo na hora (usado ao teletransportar)
func parar() -> void:
	_tipo = Tipo.NENHUM
	_apice_feito = false
	_redoma_viva = false
	_redoma_saindo = false
	_a_espiral = 0.0
	_a_redoma = 0.0
	_fase_fechada = 0.0
	_hist[0].clear()
	_hist[1].clear()
	_ondas.clear()
	_ecos.clear()
	_segs.clear()
	for emissor in _faiscas:
		emissor.emitting = false
	for emissor in _faiscas_redoma:
		emissor.emitting = false
	_faiscas_borda.emitting = false
	_jato.emitting = false
	_atualizar_linhas()
	queue_redraw()
	if _camada_tras:
		_camada_tras.queue_redraw()

func _ao_mudar_tipo(novo: int) -> void:
	var antes := _tipo
	_tipo = novo
	_apice_feito = false
	if novo != Tipo.NENHUM:
		_hist[0].clear()
		_hist[1].clear()
		_acumulo = 0.0
	# Começou uma defesa nova: a redoma recomeça do zero (mesmo que a anterior ainda estivesse sumindo)
	if novo == Tipo.DEFESA:
		_redoma_viva = false
		_redoma_saindo = false
		_fase_fechada = 0.0
		_redoma_t = 0.0
		_ecos.clear()
	# Saiu da defesa com a redoma acesa: ela se desfaz
	if antes == Tipo.DEFESA and (_redoma_viva or _a_redoma > 0.01):
		_comecar_saida_redoma()

# --- RASTRO ---
func _registrar(i: int, pos: Vector2) -> void:
	var h: Array = _hist[i]
	var andou := true
	if not h.is_empty():
		var ultimo: Vector2 = h[h.size() - 1]
		andou = ultimo.distance_to(pos) > 1.5
	if andou:
		h.append(pos)
	while h.size() > pontos_do_rastro:
		h.pop_front()

func _recolher(delta: float) -> void:
	_acumulo += recolher_rastro * delta
	var n := int(_acumulo)
	_acumulo -= float(n)
	for k in n:
		for i in 2:
			var h: Array = _hist[i]
			if not h.is_empty():
				h.pop_front()

func _atualizar_linhas() -> void:
	for i in 2:
		var h: Array = _hist[i]
		var pontos := PackedVector2Array()
		for p in h:
			pontos.append(to_local(p))
		var mostrar := rastro_ativo and pontos.size() >= 2
		_halos[i].points = pontos
		_nucleos[i].points = pontos
		_halos[i].visible = mostrar
		_nucleos[i].visible = mostrar

# --- AUGE ---
func _no_auge(_origem: Vector2, ponta_a: Vector2, ponta_b: Vector2) -> void:
	if _tipo == Tipo.ATAQUE:
		if explosao_ativa:
			var onde := ponta_a.lerp(ponta_b, 0.5)
			if ataque_a_distancia:
				# A ponta se desprende: só um cone de faíscas para a frente
				_faiscas_da_explosao(onde, int(quantidade_explosao * 0.5), 70.0, velocidade_explosao * 0.8)
			else:
				_faiscas_da_explosao(onde, quantidade_explosao)
				_adicionar_onda(onde, raio_onda_ataque)
	elif _tipo == Tipo.PROPULSOR:
		# O impulso nasce do golpe das fitas: estouro apenas nas duas pontas.
		_estouro_propulsor(ponta_a, _dir)
		_estouro_propulsor(ponta_b, _dir)
	elif _tipo == Tipo.DEFESA and redoma_ativa:
		# A redoma fechou: eco de onda, faíscas se soltando da borda e o miolo acende
		_redoma_viva = true
		_redoma_saindo = false
		_redoma_t = 0.0
		_adicionar_ecos()
		if explosao_ativa:
			_faiscas_da_redoma(quantidade_estouro_redoma, 90.0)

func _comecar_saida_redoma() -> void:
	if _redoma_viva and explosao_ativa:
		_faiscas_da_redoma(maxi(int(float(quantidade_estouro_redoma) / 2.0), 4), 35.0)   # A borda se desfaz em faíscas
	_redoma_viva = false
	_redoma_saindo = true

func _adicionar_onda(onde: Vector2, raio: float) -> void:
	_ondas.append({"pos": onde, "t": 0.0, "dur": duracao_onda, "raio": raio})

# Cada eco é a forma da redoma crescendo e sumindo; o seguinte sai um instante depois, mais fraco e menor
func _adicionar_ecos() -> void:
	for k in range(maxi(quantidade_ecos, 1)):
		_ecos.append({"t": -0.09 * float(k), "forca": 1.0 - 0.4 * float(k), "tam": 1.0 - 0.3 * float(k)})

# Estouro nas pontas no instante em que o golpe do lenço produz o segundo pulo.
func _estouro_propulsor(onde: Vector2, direcao: Vector2) -> void:
	if not explosao_ativa:
		return
	_dir = direcao
	_faiscas_da_explosao(onde, maxi(1, int(float(quantidade_estouro_jato) / 2.0)), abertura_jato * 1.6, velocidade_jato * 1.2)

# Faíscas rápidas em qualquer ponto (usado pela ponta lançada: lançamento, impacto, retorno e troca de modo)
func faiscas_em(onde: Vector2, quantidade: int, velocidade: float = -1.0) -> void:
	_faiscas_da_explosao(onde, quantidade, 180.0, velocidade)

func _faiscas_da_explosao(onde: Vector2, quantidade: int, abertura: float = 180.0, velocidade: float = -1.0) -> void:
	var p := CPUParticles2D.new()
	OpheliaEfeitosComuns.configurar_emissor(p)
	p.texture = OpheliaEfeitosComuns.textura_cintilo()
	p.local_coords = false
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(quantidade, 1)
	p.lifetime = vida_explosao
	p.explosiveness = 1.0                         # Todas saem de uma vez: efeito de explosão
	p.direction = _dir
	p.spread = abertura                           # 180 = todos os lados; menos = cone na direção apontada
	p.gravity = Vector2(0, 40)
	var vel := velocidade_explosao if velocidade < 0.0 else velocidade
	p.initial_velocity_min = vel * 0.4
	p.initial_velocity_max = vel
	p.damping_min = 80.0
	p.damping_max = 160.0
	p.scale_amount_min = 0.4 * tamanho_explosao
	p.scale_amount_max = 1.1 * tamanho_explosao
	p.scale_amount_curve = _curva_encolher()
	p.color = OpheliaEfeitosComuns.cor_particula()
	p.material = _mat
	add_child(p)
	p.global_position = onde
	p.emitting = true
	get_tree().create_timer(vida_explosao + 0.4).timeout.connect(p.queue_free)

# Faíscas que nascem ao longo da borda da redoma e saem para fora (perpendicular à borda)
func _faiscas_da_redoma(quantidade: int, velocidade: float) -> void:
	if _contorno_rel.size() < 3:
		return
	var pontos := PackedVector2Array()
	var normais := PackedVector2Array()
	var passo := maxi(int(float(_contorno_rel.size()) / 28.0), 1)
	for k in range(0, _contorno_rel.size(), passo):
		var q := _contorno_rel[k]
		pontos.append(q)
		normais.append((q - _centroide_rel).normalized())
	var p := CPUParticles2D.new()
	OpheliaEfeitosComuns.configurar_emissor(p)
	p.texture = OpheliaEfeitosComuns.textura_cintilo()
	p.local_coords = false
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(quantidade, 1)
	p.lifetime = vida_explosao
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_DIRECTED_POINTS
	p.emission_points = pontos
	p.emission_normals = normais
	p.direction = Vector2.RIGHT                   # Com pontos direcionados, "direita" = saindo pela normal da borda
	p.spread = 25.0
	p.gravity = Vector2(0, 30)
	p.initial_velocity_min = velocidade * 0.4
	p.initial_velocity_max = velocidade
	p.damping_min = 60.0
	p.damping_max = 120.0
	p.scale_amount_min = 0.4 * tamanho_explosao
	p.scale_amount_max = 1.0 * tamanho_explosao
	p.scale_amount_curve = _curva_encolher()
	p.color = OpheliaEfeitosComuns.cor_particula()
	p.material = _mat
	add_child(p)
	p.global_position = _def_centro
	p.emitting = true
	get_tree().create_timer(vida_explosao + 0.4).timeout.connect(p.queue_free)

# --- INTENSIDADES ---
func _atualizar_luz(delta: float) -> void:
	var espiral := _tipo == Tipo.ATAQUE and espiral_ataque_ativa
	_a_espiral = move_toward(_a_espiral, 1.0 if espiral else 0.0, delta / (0.05 if espiral else 0.25))

func _atualizar_redoma(delta: float) -> void:
	var em_defesa := _tipo == Tipo.DEFESA and redoma_ativa
	if em_defesa:
		_a_redoma = move_toward(_a_redoma, 1.0, delta / 0.05)
	else:
		_a_redoma = move_toward(_a_redoma, 0.0, delta / maxf(duracao_sumir_redoma, 0.01))
		if _redoma_saindo and _a_redoma <= 0.001:
			_redoma_saindo = false
			_fase_fechada = 0.0

	if _redoma_viva:
		_redoma_t += delta
		_fase_fechada = clampf(_redoma_t / 0.25, 0.0, 1.0)
	elif not _redoma_saindo and not em_defesa:
		_fase_fechada = 0.0

	# Faíscas flutuando na borda enquanto a redoma estiver fechada
	_faiscas_borda.emitting = _redoma_viva and brilhos_na_redoma > 0.0 and _contorno_rel.size() >= 3
	if _faiscas_borda.emitting:
		_faiscas_borda.global_position = _def_centro
		_faiscas_borda.emission_points = _contorno_rel

# --- FITAS DE LUZ DO ATAQUE (espiral, desligada por padrão) ---
# Monta os segmentos (no mundo). Cada um guarda se está na frente ou atrás do corpo.
func _gerar_luz() -> void:
	_segs.clear()
	if _a_espiral <= 0.01:
		return
	var qtd := maxi(fitas_espiral_ataque, 1)
	var perp := Vector2(-_esp_dir.y, _esp_dir.x)
	var passos := 28
	for j in qtd:
		var fase := TAU * float(j) / float(qtd)
		var anterior := Vector2.ZERO
		var prof_ant := 0.0
		for k in range(passos + 1):
			var s := float(k) / float(passos)
			var casca := pow(sin(PI * s), 0.8)
			var fi := _giro_ataque - TAU * voltas_espiral_ataque * s + fase
			var pos := _esp_origem + _esp_dir * (_esp_comp * s) + perp * (raio_espiral_ataque * casca * sin(fi))
			var prof := cos(fi)                       # > 0: virada para o jogador
			if k > 0:
				var luz := 0.5 + 0.25 * (prof + prof_ant)
				var afina := 0.3 + 0.7 * casca
				_segs.append({"a": anterior, "b": pos, "w": largura_espiral_ataque * (0.4 + 0.6 * luz) * afina,
						"c": _a_espiral * (0.35 + 0.65 * luz) * afina, "f": true})
			anterior = pos
			prof_ant = prof

# --- DESENHO ---
func _atualizar_desenho(delta: float) -> void:
	_gerar_luz()

	var i := _ondas.size() - 1
	while i >= 0:
		_ondas[i]["t"] += delta
		if _ondas[i]["t"] >= _ondas[i]["dur"]:
			_ondas.remove_at(i)
		i -= 1

	i = _ecos.size() - 1
	while i >= 0:
		_ecos[i]["t"] += delta
		if _ecos[i]["t"] >= duracao_eco:
			_ecos.remove_at(i)
		i -= 1

	var ha_desenho := not _ondas.is_empty() or not _ecos.is_empty() or _a_espiral > 0.01 or _a_redoma > 0.01
	if ha_desenho or _havia_desenho:
		queue_redraw()   # Redesenha também uma vez depois de acabar, para limpar
		if _camada_tras:
			_camada_tras.queue_redraw()
	_havia_desenho = ha_desenho

# Camada da FRENTE (sobre o corpo)
func _draw() -> void:
	var claro := _cor.lerp(Color.WHITE, 0.55)

	for onda in _ondas:
		var p: float = clampf(onda["t"] / onda["dur"], 0.0, 1.0)
		var e := 1.0 - pow(1.0 - p, 3.0)          # Sai rápido e desacelera
		var a := 1.0 - p
		var centro := to_local(onda["pos"])
		var raio: float = onda["raio"] * e

		# Clarão no instante da explosão
		if p < 0.3:
			draw_circle(centro, onda["raio"] * 0.35 * (1.0 - p / 0.3), Color(claro, 0.7 * (1.0 - p / 0.3)))

		draw_arc(centro, raio, 0.0, TAU, 48, Color(claro, a), lerpf(5.0, 1.0, p), true)
		draw_arc(centro, raio * 0.72, 0.0, TAU, 40, Color(_cor, a * 0.55), lerpf(3.0, 1.0, p), true)

	_desenhar_luz(self, true, claro)
	_desenhar_luz_na_fita(self, _fita_a_rel, claro)
	_desenhar_ecos(claro)

# Camada de TRÁS (atrás do corpo): fundo da redoma e a luz da fita de trás
func _desenhar_tras() -> void:
	if _camada_tras == null:
		return
	var claro := _cor.lerp(Color.WHITE, 0.55)
	_desenhar_luz(_camada_tras, false, claro)
	_desenhar_fundo_redoma(claro)
	_desenhar_luz_na_fita(_camada_tras, _fita_b_rel, claro)

func _desenhar_luz(alvo: Node2D, frente: bool, claro: Color) -> void:
	for seg in _segs:
		if seg["f"] != frente:
			continue
		var a := alvo.to_local(seg["a"])
		var b := alvo.to_local(seg["b"])
		alvo.draw_line(a, b, Color(_cor, seg["c"] * 0.6), seg["w"] * 1.8, true)       # Halo
		alvo.draw_line(a, b, Color(claro, seg["c"]), seg["w"] * 0.6, true)            # Miolo

# Luz que corre por cima de uma fita da redoma. Enquanto desenha, é mais forte na ponta (que carrega um brilho);
# depois de fechar, fica uniforme com um brilho que passeia pela fita.
func _desenhar_luz_na_fita(alvo: Node2D, fita_rel: PackedVector2Array, claro: Color) -> void:
	if _a_redoma <= 0.01 or fita_rel.size() < 2:
		return
	var curva := _curva_suave(fita_rel, 4)
	var m := curva.size()
	var pontos := PackedVector2Array()
	var cores_halo := PackedColorArray()
	var cores_miolo := PackedColorArray()
	for j in m:
		var t := float(j) / float(m - 1)
		var na_ponta := lerpf(0.12, 1.0, pow(t, 1.5))
		var brilho := lerpf(na_ponta, 0.6, _fase_fechada)
		brilho *= 0.8 + 0.2 * sin(_t * 12.0 - t * 14.0)     # Brilho correndo pela fita
		brilho *= _a_redoma
		pontos.append(alvo.to_local(_def_centro + curva[j]))
		cores_halo.append(Color(_cor, brilho * 0.5))
		cores_miolo.append(Color(claro, brilho))
	alvo.draw_polyline_colors(pontos, cores_halo, largura_luz_redoma * 2.2, true)
	alvo.draw_polyline_colors(pontos, cores_miolo, largura_luz_redoma * 0.7, true)

	# Brilho que anda na ponta enquanto a redoma ainda está sendo desenhada
	var cabeca := (1.0 - _fase_fechada) * _a_redoma
	if cabeca > 0.01:
		var r := tamanho_cabeca_redoma
		var ponta := pontos[m - 1]
		alvo.draw_texture_rect(_tex, Rect2(ponta - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(claro, cabeca))

# Miolo suave e brilho da borda, por trás do corpo (aparece quando a redoma fecha)
func _desenhar_fundo_redoma(claro: Color) -> void:
	if _contorno_rel.size() < 3 or _a_redoma <= 0.01 or _fase_fechada <= 0.0:
		return
	var f := smoothstep(0.0, 1.0, _fase_fechada) * _a_redoma
	var pontos := PackedVector2Array()
	for q in _contorno_rel:
		pontos.append(_camada_tras.to_local(_def_centro + q))
	_camada_tras.draw_colored_polygon(pontos, Color(_cor, opacidade_redoma * f))
	pontos.append(pontos[0])
	_camada_tras.draw_polyline(pontos, Color(_cor, 0.08 * f), 22.0, true)
	_camada_tras.draw_polyline(pontos, Color(_cor, 0.14 * f), 11.0, true)
	_camada_tras.draw_polyline(pontos, Color(claro, 0.30 * f), 2.0, true)

# Eco de onda: a própria forma da redoma cresce a partir da borda, afina e some
func _desenhar_ecos(claro: Color) -> void:
	if _contorno_rel.size() < 3:
		return
	for eco in _ecos:
		if eco["t"] < 0.0:
			continue   # Ainda esperando a vez
		var p: float = clampf(eco["t"] / maxf(duracao_eco, 0.01), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - p, 3.0)          # Sai rápido e desacelera
		var a: float = (1.0 - p) * eco["forca"]
		var esc: float = 1.0 + expansao_eco * e * eco["tam"]
		var pontos := PackedVector2Array()
		for q in _contorno_rel:
			pontos.append(to_local(_def_centro + _centroide_rel + (q - _centroide_rel) * esc))
		pontos.append(pontos[0])
		draw_polyline(pontos, Color(_cor, a * 0.35), lerpf(10.0, 3.0, p), true)
		draw_polyline(pontos, Color(claro, a), lerpf(3.5, 1.0, p), true)

# --- CURVAS ---
# Curva suave (Catmull-Rom) passando pelos pontos de uma fita
func _curva_suave(pts: PackedVector2Array, sub: int) -> PackedVector2Array:
	var saida := PackedVector2Array()
	var n := pts.size()
	for i in range(n - 1):
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, n - 1)]
		for s in range(sub):
			saida.append(p1.cubic_interpolate(p2, p0, p3, float(s) / float(sub)))
	saida.append(pts[n - 1])
	return saida

# Igual, mas fechando a volta (último ponto liga no primeiro)
func _contorno_fechado(pts: PackedVector2Array, sub: int) -> PackedVector2Array:
	var saida := PackedVector2Array()
	var n := pts.size()
	if n < 3:
		return pts
	for i in range(n):
		var p0 := pts[(i - 1 + n) % n]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		var p3 := pts[(i + 2) % n]
		for s in range(sub):
			saida.append(p1.cubic_interpolate(p2, p0, p3, float(s) / float(sub)))
	return saida

# --- CRIAÇÃO DOS NÓS ---
func _nova_linha(largura: float) -> Line2D:
	var linha := Line2D.new()
	linha.width = largura
	linha.width_curve = _curva_largura()
	linha.begin_cap_mode = Line2D.LINE_CAP_ROUND
	linha.end_cap_mode = Line2D.LINE_CAP_ROUND
	linha.joint_mode = Line2D.LINE_JOINT_ROUND
	linha.material = _mat
	linha.visible = false
	add_child(linha)
	return linha

func _novo_emissor() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	OpheliaEfeitosComuns.configurar_emissor(p)
	p.texture = OpheliaEfeitosComuns.textura_cintilo()
	p.local_coords = false             # As faíscas ficam no mundo e formam a trilha
	p.emitting = false
	p.amount = maxi(4, int(faiscas_por_segundo * vida_faisca * 0.5))
	p.lifetime = vida_faisca
	p.explosiveness = 0.0
	p.spread = 180.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 50.0
	p.gravity = Vector2(0, -25)        # Sobem de leve, como brasas
	p.damping_min = 20.0
	p.damping_max = 40.0
	p.scale_amount_min = 0.3 * tamanho_faisca
	p.scale_amount_max = 0.8 * tamanho_faisca
	p.scale_amount_curve = _curva_encolher()
	p.material = _mat
	return p

# Faíscas das pontas enquanto desenham a redoma (mais densas que as do feixe comum)
func _novo_emissor_ponta_redoma() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	OpheliaEfeitosComuns.configurar_emissor(p)
	p.texture = OpheliaEfeitosComuns.textura_cintilo()
	p.local_coords = false
	p.emitting = false
	p.amount = maxi(8, int(faiscas_ponta_redoma * vida_faisca_redoma))
	p.lifetime = vida_faisca_redoma
	p.explosiveness = 0.0
	p.spread = 180.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 55.0
	p.gravity = Vector2(0, -30)
	p.damping_min = 20.0
	p.damping_max = 45.0
	p.scale_amount_min = 0.35 * tamanho_faisca
	p.scale_amount_max = 0.9 * tamanho_faisca
	p.scale_amount_curve = _curva_encolher()
	p.material = _mat
	return p

# Jato de faíscas do propulsor (sai das pontas, para o lado apontado)
func _novo_emissor_jato() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	OpheliaEfeitosComuns.configurar_emissor(p)
	p.texture = OpheliaEfeitosComuns.textura_cintilo()
	p.local_coords = false
	p.emitting = false
	p.amount = maxi(8, int(faiscas_do_jato * vida_jato))
	p.lifetime = vida_jato
	p.explosiveness = 0.0
	p.direction = Vector2.RIGHT
	p.spread = abertura_jato
	p.initial_velocity_min = velocidade_jato * 0.5
	p.initial_velocity_max = velocidade_jato
	p.gravity = Vector2.ZERO
	p.damping_min = 30.0
	p.damping_max = 70.0
	p.scale_amount_min = 0.4 * tamanho_jato
	p.scale_amount_max = 1.0 * tamanho_jato
	p.scale_amount_curve = _curva_encolher()
	p.material = _mat
	return p

# Faíscas que nascem na borda da redoma fechada e sobem devagar
func _novo_emissor_borda() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	OpheliaEfeitosComuns.configurar_emissor(p)
	p.texture = OpheliaEfeitosComuns.textura_cintilo()
	p.local_coords = false
	p.emitting = false
	p.amount = maxi(6, int(brilhos_na_redoma * 0.9))
	p.lifetime = 0.9
	p.explosiveness = 0.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = PackedVector2Array([Vector2.ZERO])   # Trocado todo quadro pela borda da redoma
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 26.0
	p.gravity = Vector2(0, -20)
	p.scale_amount_min = 0.3 * tamanho_faisca
	p.scale_amount_max = 0.9 * tamanho_faisca
	p.scale_amount_curve = _curva_encolher()
	p.material = _mat
	return p

func _aplicar_cor() -> void:
	var claro := _cor.lerp(Color.WHITE, 0.6)
	for i in _halos.size():
		_halos[i].gradient = _gradiente(_cor, 0.65)
		_nucleos[i].gradient = _gradiente(claro, 1.0)
	for emissor in _faiscas:
		emissor.color = OpheliaEfeitosComuns.cor_particula()
	for emissor in _faiscas_redoma:
		emissor.color = OpheliaEfeitosComuns.cor_particula()
	if _faiscas_borda:
		_faiscas_borda.color = OpheliaEfeitosComuns.cor_particula()
	if _jato:
		_jato.color = OpheliaEfeitosComuns.cor_particula()

# Do transparente (rabo do feixe) até a cor cheia (ponta)
func _gradiente(c: Color, alfa_final: float) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(c.r, c.g, c.b, 0.0), Color(c.r, c.g, c.b, alfa_final)])
	return g

func _curva_largura() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.05))
	c.add_point(Vector2(0.65, 0.6))
	c.add_point(Vector2(1.0, 1.0))
	return c

func _curva_encolher() -> Curve:
	return OpheliaEfeitosComuns.curva_encolher()

func _criar_textura() -> Texture2D:
	return OpheliaEfeitosComuns.textura_radial(16)
