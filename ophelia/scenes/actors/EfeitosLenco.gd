class_name EfeitosLenco
extends Node2D
# Efeitos especiais do ataque e da defesa do lenço.
#   Ataque: feixe de luz seguindo as pontas e uma explosão (faíscas e anel) quando a figura chega ao auge.
#   Defesa: feixe de luz seguindo as pontas; no auge cada ponta explode e, a partir das duas explosões,
#           um arco de luz se forma entre elas.
# O PontoOrigem cria e comanda este nó sozinho (com os valores padrão). Para ajustar no Inspetor,
# adicione um Node2D chamado "EfeitosLenco" como filho do PontoOrigem e anexe este script.

enum Tipo { NENHUM, ATAQUE, DEFESA }

@export_group("Cor")
@export var usar_cor_do_lenco: bool = true               # true: usa a cor das fitas, clareada para brilhar
@export var cor_manual: Color = Color(0.85, 0.45, 1.0)   # Usada quando 'usar_cor_do_lenco' está desmarcado
@export_range(0.0, 1.0) var saturacao_minima: float = 0.4

@export_group("Rastro (feixe de luz)")
@export var rastro_ativo: bool = true
@export var pontos_do_rastro: int = 18                   # Comprimento do feixe
@export var largura_do_rastro: float = 9.0
@export var recolher_rastro: float = 70.0                # Pontos apagados por segundo depois do auge (velocidade de sumir)

@export_group("Faíscas do feixe")
@export var faiscas_ativas: bool = true
@export var faiscas_por_segundo: float = 70.0
@export var vida_faisca: float = 0.45
@export var tamanho_faisca: float = 0.7

@export_group("Explosão no auge")
@export var explosao_ativa: bool = true
@export var quantidade_explosao: int = 26                # Ataque: faíscas da explosão
@export var quantidade_explosao_defesa: int = 18         # Defesa: faíscas de CADA ponta
@export var velocidade_explosao: float = 240.0
@export var vida_explosao: float = 0.6
@export var tamanho_explosao: float = 0.9
@export var raio_onda_ataque: float = 60.0               # Anel do ataque
@export var raio_onda_defesa: float = 34.0               # Anel em cada ponta, na defesa
@export var duracao_onda: float = 0.38

@export_group("Arco da defesa")
@export var arco_ativo: bool = true
@export var curvatura_arco: float = 0.45                 # Quanto o arco estufa para fora (fração da distância entre as pontas)
@export var largura_arco: float = 7.0
@export var duracao_formar_arco: float = 0.22            # Tempo para os dois feixes se encontrarem
@export var duracao_barreira: float = 0.35               # Tempo com o arco inteiro aceso
@export var duracao_sumir_arco: float = 0.3
@export_range(0.0, 1.0) var brilho_barreira: float = 0.15   # Preenchimento suave entre o arco e as pontas

var _tipo: int = Tipo.NENHUM
var _apice_feito: bool = false
var _cor: Color = Color(0.7, 0.7, 1.0)
var _dir: Vector2 = Vector2.RIGHT
var _acumulo: float = 0.0
var _tex: Texture2D = null
var _mat: CanvasItemMaterial = null

var _halos: Array[Line2D] = []      # Feixe largo e suave (um por fita)
var _nucleos: Array[Line2D] = []    # Miolo fino e claro do feixe
var _faiscas: Array[CPUParticles2D] = []
var _hist: Array = [[], []]         # Posições recentes (no mundo) de cada ponta
var _ondas: Array = []              # Anéis em expansão
var _havia_desenho: bool = false

# Arco da defesa (entre as duas pontas)
var _arco_ativo: bool = false
var _arco_t: float = 0.0
var _arco_a: Vector2 = Vector2.ZERO
var _arco_b: Vector2 = Vector2.ZERO

func _ready() -> void:
	_mat = CanvasItemMaterial.new()
	_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD   # Soma luz em vez de cobrir
	material = _mat
	_tex = _criar_textura()

	for i in 2:
		_halos.append(_nova_linha(largura_do_rastro))
		_nucleos.append(_nova_linha(largura_do_rastro * 0.35))
		var emissor := _novo_emissor()
		add_child(emissor)
		_faiscas.append(emissor)
	_aplicar_cor()

# --- API (chamada pelo PontoOrigem) ---

# Define a cor a partir da cor das fitas
func configurar_cor(cor_lenco: Color) -> void:
	if usar_cor_do_lenco:
		var sat := clampf(maxf(cor_lenco.s * 1.2, saturacao_minima), 0.0, 0.85)
		_cor = Color.from_hsv(cor_lenco.h, sat, 1.0)
	else:
		_cor = cor_manual
	_aplicar_cor()

# Chamado todo quadro. 'progresso' vai de 0 a 1 enquanto a figura se forma; em 1 é o auge.
func atualizar(delta: float, tipo: int, direcao: Vector2, progresso: float,
		ponta_a: Vector2, ponta_b: Vector2) -> void:
	if tipo != _tipo:
		_tipo = tipo
		_apice_feito = false
		_arco_ativo = false
		if tipo != Tipo.NENHUM:
			_hist[0].clear()
			_hist[1].clear()
			_acumulo = 0.0

	var formando := _tipo != Tipo.NENHUM and progresso < 1.0
	if _tipo != Tipo.NENHUM:
		_dir = direcao

	# Feixe: grava o caminho das pontas durante o movimento rápido; depois do auge ele vai sumindo
	if formando:
		_registrar(0, ponta_a)
		_registrar(1, ponta_b)
	else:
		_recolher(delta)

	# Faíscas acompanham as pontas enquanto a figura se forma
	_faiscas[0].global_position = ponta_a
	_faiscas[1].global_position = ponta_b
	_faiscas[0].emitting = faiscas_ativas and formando
	_faiscas[1].emitting = faiscas_ativas and formando

	# O arco acompanha as pontas enquanto a defesa durar; depois fica onde estava e some
	if _arco_ativo and _tipo == Tipo.DEFESA:
		_arco_a = ponta_a
		_arco_b = ponta_b

	# Auge: a explosão acontece uma vez
	if _tipo != Tipo.NENHUM and progresso >= 1.0 and not _apice_feito:
		_apice_feito = true
		_explodir(ponta_a, ponta_b)

	_atualizar_linhas()
	_atualizar_desenho(delta)

# Apaga tudo na hora (usado ao teletransportar)
func parar() -> void:
	_tipo = Tipo.NENHUM
	_apice_feito = false
	_arco_ativo = false
	_hist[0].clear()
	_hist[1].clear()
	_ondas.clear()
	for emissor in _faiscas:
		emissor.emitting = false
	_atualizar_linhas()
	queue_redraw()

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
func _explodir(ponta_a: Vector2, ponta_b: Vector2) -> void:
	if _tipo == Tipo.ATAQUE:
		if explosao_ativa:
			var onde := ponta_a.lerp(ponta_b, 0.5)
			_faiscas_da_explosao(onde, quantidade_explosao)
			_adicionar_onda(onde, raio_onda_ataque)
		return

	# Defesa: uma explosão em CADA ponta e, a partir delas, um arco se forma entre as duas
	if explosao_ativa:
		for ponta in [ponta_a, ponta_b]:
			_faiscas_da_explosao(ponta, quantidade_explosao_defesa)
			_adicionar_onda(ponta, raio_onda_defesa)
	if arco_ativo:
		_arco_ativo = true
		_arco_t = 0.0
		_arco_a = ponta_a
		_arco_b = ponta_b

func _adicionar_onda(onde: Vector2, raio: float) -> void:
	_ondas.append({"pos": onde, "t": 0.0, "dur": duracao_onda, "raio": raio})

func _faiscas_da_explosao(onde: Vector2, quantidade: int) -> void:
	var p := CPUParticles2D.new()
	p.texture = _tex
	p.local_coords = false
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(quantidade, 1)
	p.lifetime = vida_explosao
	p.explosiveness = 1.0                         # Todas saem de uma vez: efeito de explosão
	p.direction = _dir
	p.spread = 180.0                              # Espalha para todos os lados
	p.gravity = Vector2(0, 40)
	p.initial_velocity_min = velocidade_explosao * 0.4
	p.initial_velocity_max = velocidade_explosao
	p.damping_min = 80.0
	p.damping_max = 160.0
	p.scale_amount_min = 0.4 * tamanho_explosao
	p.scale_amount_max = 1.1 * tamanho_explosao
	p.scale_amount_curve = _curva_encolher()
	p.color = _cor
	p.material = _mat
	add_child(p)
	p.global_position = onde
	p.emitting = true
	get_tree().create_timer(vida_explosao + 0.4).timeout.connect(p.queue_free)

# --- ANÉIS E ARCO (desenhados) ---
func _atualizar_desenho(delta: float) -> void:
	var i := _ondas.size() - 1
	while i >= 0:
		_ondas[i]["t"] += delta
		if _ondas[i]["t"] >= _ondas[i]["dur"]:
			_ondas.remove_at(i)
		i -= 1

	if _arco_ativo:
		_arco_t += delta
		if _arco_t >= duracao_formar_arco + duracao_barreira + duracao_sumir_arco:
			_arco_ativo = false

	var ha_desenho := not _ondas.is_empty() or _arco_ativo
	if ha_desenho or _havia_desenho:
		queue_redraw()   # Redesenha também uma vez depois de acabar, para limpar
	_havia_desenho = ha_desenho

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

	_desenhar_arco(claro)

# Arco da defesa: cada ponta lança um feixe ao longo da curva; os dois se encontram e fecham o arco
func _desenhar_arco(claro: Color) -> void:
	if not _arco_ativo:
		return
	var corda := _arco_b - _arco_a
	var comp := corda.length()
	if comp < 1.0:
		return

	var g := clampf(_arco_t / maxf(duracao_formar_arco, 0.01), 0.0, 1.0)
	var e := 1.0 - pow(1.0 - g, 2.0)             # Os feixes saem rápido das pontas e desaceleram ao se encontrar
	var fim_aceso := duracao_formar_arco + duracao_barreira
	var a := 1.0
	if _arco_t > fim_aceso:
		a = 1.0 - clampf((_arco_t - fim_aceso) / maxf(duracao_sumir_arco, 0.01), 0.0, 1.0)

	# Curva entre as duas pontas, estufada para o lado em que a defesa aponta
	var normal := Vector2(-corda.y, corda.x) / comp
	if normal.dot(_dir) < 0.0:
		normal = -normal
	var ctrl := (_arco_a + _arco_b) * 0.5 + normal * (2.0 * curvatura_arco * comp)

	# Preenchimento suave quando os feixes estão quase se encontrando
	var enchimento := brilho_barreira * a * smoothstep(0.6, 1.0, g)
	if enchimento > 0.001:
		draw_colored_polygon(_pontos_arco(ctrl, 0.0, 1.0), Color(_cor, enchimento))

	# Os dois feixes (um de cada ponta). Com g = 1 viram um arco inteiro.
	var meio := e * 0.5
	var trechos: Array = []
	if g >= 1.0:
		trechos.append([0.0, 1.0])
	else:
		trechos.append([0.0, meio])
		trechos.append([1.0 - meio, 1.0])
	for trecho in trechos:
		if trecho[1] - trecho[0] < 0.01:
			continue
		var pontos := _pontos_arco(ctrl, trecho[0], trecho[1])
		draw_polyline(pontos, Color(_cor, 0.55 * a), largura_arco, true)
		draw_polyline(pontos, Color(claro, a), largura_arco * 0.35, true)

	# Cabeça brilhante de cada feixe enquanto ele ainda anda
	if g < 1.0:
		for u in [meio, 1.0 - meio]:
			draw_circle(to_local(_ponto_do_arco(ctrl, u)), largura_arco * 0.7, Color(claro, a))

# Ponto da curva (Bézier) entre as pontas; u = 0 é a ponta A e u = 1 é a ponta B
func _ponto_do_arco(ctrl: Vector2, u: float) -> Vector2:
	var m := 1.0 - u
	return _arco_a * (m * m) + ctrl * (2.0 * m * u) + _arco_b * (u * u)

func _pontos_arco(ctrl: Vector2, u0: float, u1: float) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	var passos := 24
	for k in range(passos + 1):
		pontos.append(to_local(_ponto_do_arco(ctrl, lerpf(u0, u1, float(k) / float(passos)))))
	return pontos

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
	p.texture = _tex
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

func _aplicar_cor() -> void:
	var claro := _cor.lerp(Color.WHITE, 0.6)
	for i in _halos.size():
		_halos[i].gradient = _gradiente(_cor, 0.65)
		_nucleos[i].gradient = _gradiente(claro, 1.0)
	for emissor in _faiscas:
		emissor.color = _cor

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
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c

# Mancha redonda e macia: centro forte, borda transparente
func _criar_textura() -> Texture2D:
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
	return t
